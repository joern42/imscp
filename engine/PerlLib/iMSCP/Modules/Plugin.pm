=head1 NAME

 iMSCP::Modules::Plugin - Module for processing of i-MSCP plugins

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

package iMSCP::Modules::Plugin;

use strict;
use warnings;
use Hash::Merge qw/ merge /;
use iMSCP::Database;
use iMSCP::Debug qw/ debug /;
use iMSCP::EventManager;
use iMSCP::Getopt;
use iMSCP::Plugins;
use JSON;
use LWP::Simple qw/ $ua get /;
use version;
use parent 'iMSCP::Common::Object';

=head1 DESCRIPTION

 This module provides the backend side of the i-MSCP plugin manager. It is
 responsible to execute one or many actions on a particular plugin according
 its current state.
 
 The plugin is instantiated with the following parameters:
  action      : Plugin master action
  config      : Plugin current configuration
  config_prev : Plugin previous configuration
  eventManager: EventManager instance
  info        : Plugin info

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ($self) = @_;

    'Plugin';
}

=item handleEntity( $entityId )

 See iMSCP::Modules::Abstract::handleEntity()

=cut

sub handleEntity
{
    my ($self, $entityId) = @_;

    $self->{'pluginId'} = $entityId;

    eval {
        $self->_loadEntityData( $entityId );

        my $method;
        if ( $self->{'pluginStatus'} eq 'enabled' ) {
            $self->{'pluginAction'} = 'run';
            $method = '_run'
        } elsif ( $self->{'pluginStatus'} =~ /^to(install|change|update|uninstall|enable|disable)$/ ) {
            $self->{'pluginAction'} = $1;
            $method = '_' . $self->{'pluginAction'};
        } else {
            die( sprintf( 'Unknown plugin status: %s', $self->{'pluginStatus'} ));
        }

        $self->$method();
        $self->{'eventManager'}->trigger( 'onBeforeSetPluginStatus', $self->{'pluginName'}, \$self->{'pluginStatus'} );
    };

    return $self unless $@ || $self->{'pluginAction'} ne 'run';

    my %pluginNextStateMap = (
        toinstall   => 'enabled',
        toenable    => 'enabled',
        toupdate    => 'enabled',
        tochange    => 'enabled',
        todisable   => 'disabled',
        touninstall => 'uninstalled'
    );

    $self->{'dbh'}->do(
        "UPDATE plugin SET " . ( $@ ? 'plugin_error' : 'plugin_status' ) . " = ? WHERE plugin_id = ?",
        undef,
        ( $@ ? $@ : $pluginNextStateMap{$self->{'pluginStatus'}} ),
        $entityId
    );

    return $self if iMSCP::Getopt->context() eq 'installer';

    my $cacheIds = 'iMSCP_Plugin_Manager_Metadata';
    $cacheIds .= ";$self->{'pluginInfo'}->{'require_cache_flush'}" if $self->{'pluginInfo'}->{'require_cache_flush'};
    my $httpScheme = $main::imscpConfig{'BASE_SERVER_VHOST_PREFIX'};
    my $url = "${httpScheme}127.0.0.1:" . ( $httpScheme eq 'http://'
        ? $main::imscpConfig{'BASE_SERVER_VHOST_HTTP_PORT'} : $main::imscpConfig{'BASE_SERVER_VHOST_HTTPS_PORT'}
    ) . "/fcache.php?ids=$cacheIds";
    get( $url ) or warn( "Couldn't trigger flush of frontEnd cache" );
    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Modules::Plugin

=cut

sub _init
{
    my ($self) = @_;

    $ua->timeout( 5 );
    $ua->agent( "i-MSCP/1.6 (+https://i-mscp.net/)" );
    $ua->ssl_opts(
        verify_hostname => 0,
        SSL_verify_mode => 0x00
    );
    $self->{'dbh'} = iMSCP::Database->getInstance();
    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    @{$self}{qw/ pluginId pluginAction pluginInstance pluginName pluginInfo pluginConfig pluginConfigPrev pluginStatus /} = undef;
    $self;
}

=item _loadEntityData( $entityId )

 See iMSCP::Modules::Abstract::_loadEntityData()

=cut

sub _loadEntityData
{
    my ($self, $entityId) = @_;

    my $row = $self->{'dbh'}->selectrow_hashref(
        'SELECT plugin_name, plugin_info, plugin_config, plugin_config_prev, plugin_status FROM plugin WHERE plugin_id = ?', undef, $entityId
    );
    $row or die( sprintf( 'Data not found for plugin with ID %d', $entityId ));
    $self->{'pluginName'} = $row->{'plugin_name'};
    $self->{'pluginInfo'} = decode_json( $row->{'plugin_info'} );
    $self->{'pluginConfig'} = decode_json( $row->{'plugin_config'} );
    $self->{'pluginConfigPrev'} = decode_json( $row->{'plugin_config_prev'} );
    $self->{'pluginStatus'} = $row->{'plugin_status'};
}

=item _install( )

 Install the plugin

 Return void, die on failure

=cut

sub _install
{
    my ($self) = @_;

    $self->{'eventManager'}->trigger( 'onBeforeInstallPlugin', $self->{'pluginName'} );
    $self->_executePluginAction( 'install' );
    $self->{'eventManager'}->trigger( 'onAfterInstallPlugin', $self->{'pluginName'} );
    $self->_enable();
}

=item _uninstall( )

 Uninstall the plugin

 Return void, die on failure

=cut

sub _uninstall
{
    my ($self) = @_;

    $self->{'eventManager'}->trigger( 'onBeforeUninstallPlugin', $self->{'pluginName'} );
    $self->_executePluginAction( 'uninstall' );
    $self->{'eventManager'}->trigger( 'onAfterUninstallPlugin', $self->{'pluginName'} );
}

=item _enable( )

 Enable the plugin

 Return void, die on failure

=cut

sub _enable
{
    my ($self) = @_;

    $self->{'eventManager'}->trigger( 'onBeforeEnablePlugin', $self->{'pluginName'} );
    $self->_executePluginAction( 'enable' );
    $self->{'eventManager'}->trigger( 'onAfterEnablePlugin', $self->{'pluginName'} );
}

=item _disable( )

 Disable the plugin

 Return void, die on failure

=cut

sub _disable
{
    my ($self) = @_;

    $self->{'eventManager'}->trigger( 'onBeforeDisablePlugin', $self->{'pluginName'} );
    $self->_executePluginAction( 'disable' );
    $self->{'eventManager'}->trigger( 'onAfterDisablePlugin', $self->{'pluginName'} );
}

=item _change( )

 Change the plugin

 Return void, die on failure

=cut

sub _change
{
    my ($self) = @_;

    $self->_disable();
    $self->{'eventManager'}->trigger( 'onBeforeChangePlugin', $self->{'pluginName'} );
    $self->_executePluginAction( 'change' );
    $self->{'eventManager'}->trigger( 'onAfterChangePlugin', $self->{'pluginName'} );

    if ( $self->{'pluginInfo'}->{'__need_change__'} ) {
        $self->{'pluginConfigPrev'} = $self->{'pluginConfig'};
        $self->{'pluginInfo'}->{'__need_change__'} = JSON::false;
        $self->{'dbh'}->do(
            'UPDATE plugin SET plugin_info = ?, plugin_config_prev = plugin_config WHERE plugin_id = ?',
            undef, encode_json( $self->{'pluginInfo'} ), $self->{'pluginId'}
        );
    }

    $self->_enable();
}

=item _update( )

 Update the plugin

 Return void, die on failure

=cut

sub _update
{
    my ($self) = @_;

    $self->_disable();
    $self->{'eventManager'}->trigger( 'onBeforeUpdatePlugin', $self->{'pluginName'} );
    $self->_executePluginAction( 'update' );
    $self->{'pluginInfo'}->{'version'} = $self->{'pluginInfo'}->{'__nversion__'};
    $self->{'dbh'}->do( 'UPDATE plugin SET plugin_info = ? WHERE plugin_id = ?', undef, encode_json( $self->{'pluginInfo'} ), $self->{'pluginId'} );
    $self->{'eventManager'}->trigger( 'onAfterUpdatePlugin', $self->{'pluginName'} );

    if ( $self->{'pluginInfo'}->{'__need_change__'} ) {
        $self->{'eventManager'}->trigger( 'onBeforeChangePlugin', $self->{'pluginName'} );
        $self->_executePluginAction( 'change' );
        $self->{'pluginConfigPrev'} = $self->{'pluginConfig'};
        $self->{'pluginInfo'}->{'__need_change__'} = JSON::false;
        $self->{'dbh'}->do(
            'UPDATE plugin SET plugin_info = ?, plugin_config_prev = plugin_config WHERE plugin_id = ?',
            undef,
            encode_json( $self->{'pluginInfo'} ), $self->{'pluginId'}
        );
        $self->{'eventManager'}->trigger( 'onAfterChangePlugin', $self->{'pluginName'} );
    }

    $self->_enable();
}

=item _run( )

 Run plugin item tasks

 Return void, die on failure

=cut

sub _run
{
    my ($self) = @_;

    $self->{'eventManager'}->trigger( 'onBeforeRunPlugin', $self->{'pluginName'} );
    $self->_executePluginAction( 'run' );
    $self->{'eventManager'}->trigger( 'onAfterRunPlugin', $self->{'pluginName'} );
}

=item _executePluginAction( $action )

 Execute the given plugin action

 Note that an exception that is raised in the context of the run() action is
 ignored by default because it is normaly the plugin responsability to update
 the entity for which the exception has been raised. However a plugin can force
 this module to bubble up the exception by setting the 'BUBBLE_EXCEPTIONS'
 property on the plugin package to a TRUE value, in which case the error will
 used tol update the plugin status.

 Param string $action Action to execute on the plugin
 Return void, die on failure

=cut

sub _executePluginAction
{
    my ($self, $action) = @_;

    unless ( $self->{'pluginInstance'} ) {
        local $SIG{'__WARN__'} = sub { die @_ }; # Turn any warning from plugin into exception
        my $pluginClass = iMSCP::Plugins->getInstance()->getClass( $self->{'pluginName'} );
        return undef unless $pluginClass->can( $action ); # Do not instantiate plugin when not necessary

        $self->{'pluginInstance'} = ( $pluginClass->can( 'getInstance' ) || $pluginClass->can( 'new' ) || die( 'Bad plugin class' ) )->(
            $pluginClass,
            action       => $self->{'pluginAction'},
            config       => $self->{'pluginConfig'},
            config_prev  => ( $self->{'pluginAction'} =~ /^(?:change|update)$/
                # On plugin change/update, make sure that prev config also contains any new parameter
                ? merge( $self->{'pluginConfigPrev'}, $self->{'pluginConfig'} ) : $self->{'pluginConfigPrev'} ),
            eventManager => $self->{'eventManager'},
            info         => $self->{'pluginInfo'}
        );
    }

    my $subref = $self->{'pluginInstance'}->can( $action ) or return;
    debug( sprintf( "Executing %s( ) action on %s", $action, ref $self->{'pluginInstance'} ));

    local $@;
    eval {
        $subref->(
            $self->{'pluginInstance'}, $action eq 'update' ? ( $self->{'pluginInfo'}->{'version'}, $self->{'pluginInfo'}->{'__nversion__'} ) : ()
        );
    };

    # In context of the run() action, exception are not bubbled up by default, unless
    # the plugin 'BUBBLE_EXCEPTIONS' property is set with a TRUE value.
    die if $@ && ( $action ne 'run' || $self->{'pluginInstance'}->{'BUBBLE_EXCEPTIONS'} )
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
