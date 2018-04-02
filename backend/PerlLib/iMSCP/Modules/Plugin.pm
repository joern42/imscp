=head1 NAME

 iMSCP::Modules::Plugin - Module for processing of i-MSCP plugins

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

package iMSCP::Modules::Plugin;

use strict;
use warnings;
use Hash::Merge qw/ merge /;
use iMSCP::Debug qw/ debug warning /;
use iMSCP::Getopt;
use iMSCP::Plugins;
use JSON;
use LWP::Simple qw/ $ua get /;
use version;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 This module provides the backend side of the i-MSCP plugin manager. It is
 responsible to execute one or many actions on the plugins according their
 current status.
 
 The plugins are instantiated with the following parameters:
  action      : Plugin master action
  config      : Plugin current configuration, that is, the new plugin configuration
  config_prev : Plugin previous configuration, that is, the older plugin configuration
  eventManager: EventManager instance
  info        : Plugin info

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ( $self ) = @_;

    'Plugin';
}

=item handleEntity( $entityId )

 See iMSCP::Modules::Abstract::handleEntity()

=cut

sub handleEntity
{
    my ( $self, $entityId ) = @_;

    eval {
        $self->_loadEntityData( $entityId );

        my $method;
        if ( $self->{'_data'}->{'plugin_status'} eq 'enabled' ) {
            $self->{'_data'}->{'plugin_action'} = 'run';
            $method = '_run'
        } elsif ( $self->{'_data'}->{'plugin_status'} =~ /^to(install|change|update|uninstall|enable|disable)$/ ) {
            $self->{'_data'}->{'plugin_action'} = $1;
            $method = '_' . $self->{'_data'}->{'plugin_action'};
        } else {
            die( sprintf( 'Unknown plugin status: %s', $self->{'_data'}->{'plugin_status'} ));
        }

        $self->$method();
        $self->{'eventManager'}->trigger( 'onBeforeSetPluginStatus', $self->{'_data'}->{'plugin_name'}, \$self->{'_data'}->{'plugin_status'} );
    };

    return $self unless $@ || $self->{'_data'}->{'plugin_action'} ne 'run';

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
        ( $@ ? $@ : $pluginNextStateMap{$self->{'plugin_status'}} ),
        $entityId
    );

    return $self if iMSCP::Getopt->context() eq 'installer';

    my $cacheIds = 'iMSCP_Plugin_Manager_Metadata';
    $cacheIds .= ";$self->{'_data'}->{'plugin_info'}->{'require_cache_flush'}" if $self->{'_data'}->{'plugin_info'}->{'require_cache_flush'};
    my $httpScheme = $::imscpConfig{'BASE_SERVER_VHOST_PREFIX'};
    my $url = "${httpScheme}127.0.0.1:" . ( $httpScheme eq 'http://'
        ? $::imscpConfig{'BASE_SERVER_VHOST_HTTP_PORT'} : $::imscpConfig{'BASE_SERVER_VHOST_HTTPS_PORT'}
    ) . "/fcache.php?ids=$cacheIds";
    get( $url ) or warning( "Couldn't trigger flush of frontEnd cache" );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Modules::Abstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $ua->timeout( 5 );
    $ua->agent( 'i-MSCP/1.6 (+https://i-mscp.net/)' );
    $ua->ssl_opts( verify_hostname => 0, SSL_verify_mode => 0x00 );
    $self->{'_plugin_instances'} = {};
    $self->SUPER::_init();
}

=item _loadEntityData( $entityId )

 See iMSCP::Modules::Abstract::_loadEntityData()

=cut

sub _loadEntityData
{
    my ( $self, $entityId ) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref(
        'SELECT plugin_name, plugin_info, plugin_config, plugin_config_prev, plugin_status FROM plugin WHERE plugin_id = ?', undef, $entityId
    );
    $row or die( sprintf( 'Data not found for plugin with ID %d', $entityId ));

    $self->{'_data'} = {
        plugin_id          => $entityId,
        plugin_name        => $row->{'plugin_name'},
        plugin_info        => decode_json( $row->{'plugin_info'} ),
        plugin_config      => decode_json( $row->{'plugin_config'} ),
        plugin_config_prev => decode_json( $row->{'plugin_config_prev'} ),
        plugin_status      => $row->{'plugin_status'}
    };
}

=item _install( )

 Install the plugin

 Return void, die on failure

=cut

sub _install
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'onBeforeInstallPlugin', $self->{'_data'}->{'plugin_name'} );
    $self->_executePluginAction( 'install' );
    $self->{'eventManager'}->trigger( 'onAfterInstallPlugin', $self->{'_data'}->{'plugin_name'} );
    $self->_enable();
}

=item _uninstall( )

 Uninstall the plugin

 Return void, die on failure

=cut

sub _uninstall
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'onBeforeUninstallPlugin', $self->{'_data'}->{'plugin_name'} );
    $self->_executePluginAction( 'uninstall' );
    $self->{'eventManager'}->trigger( 'onAfterUninstallPlugin', $self->{'_data'}->{'plugin_name'} );
}

=item _enable( )

 Enable the plugin

 Return void, die on failure

=cut

sub _enable
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'onBeforeEnablePlugin', $self->{'_data'}->{'plugin_name'} );
    $self->_executePluginAction( 'enable' );
    $self->{'eventManager'}->trigger( 'onAfterEnablePlugin', $self->{'_data'}->{'plugin_name'} );
}

=item _disable( )

 Disable the plugin

 Return void, die on failure

=cut

sub _disable
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'onBeforeDisablePlugin', $self->{'_data'}->{'plugin_name'} );
    $self->_executePluginAction( 'disable' );
    $self->{'eventManager'}->trigger( 'onAfterDisablePlugin', $self->{'_data'}->{'plugin_name'} );
}

=item _change( )

 Change the plugin

 Return void, die on failure

=cut

sub _change
{
    my ( $self ) = @_;

    $self->_disable();
    $self->{'eventManager'}->trigger( 'onBeforeChangePlugin', $self->{'_data'}->{'plugin_name'} );
    $self->_executePluginAction( 'change' );
    $self->{'eventManager'}->trigger( 'onAfterChangePlugin', $self->{'_data'}->{'plugin_name'} );

    if ( $self->{'plugin_info'}->{'__need_change__'} ) {
        $self->{'_data'}->{'plugin_config_prev'} = $self->{'_data'}->{'plugin_config'};
        $self->{'_data'}->{'plugin_info'}->{'__need_change__'} = JSON::false;
        $self->{'_data'}->{'_dbh'}->do(
            'UPDATE plugin SET plugin_info = ?, plugin_config_prev = plugin_config WHERE plugin_id = ?',
            undef,
            encode_json( $self->{'_data'}->{'plugin_info'} ),
            $self->{'_data'}->{'pluginId'}
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
    my ( $self ) = @_;

    $self->_disable();
    $self->{'eventManager'}->trigger( 'onBeforeUpdatePlugin', $self->{'_data'}->{'plugin_name'} );
    $self->_executePluginAction( 'update' );
    $self->{'_data'}->{'plugin_info'}->{'version'} = $self->{'_data'}->{'plugin_info'}->{'__nversion__'};
    $self->{'_dbh'}->do(
        'UPDATE plugin SET plugin_info = ? WHERE plugin_id = ?',
        undef,
        encode_json( $self->{'_data'}->{'plugin_info'} ),
        $self->{'_data'}->{'pluginId'}
    );
    $self->{'eventManager'}->trigger( 'onAfterUpdatePlugin', $self->{'_data'}->{'plugin_name'} );

    if ( $self->{'_data'}->{'plugin_info'}->{'__need_change__'} ) {
        $self->{'eventManager'}->trigger( 'onBeforeChangePlugin', $self->{'_data'}->{'plugin_name'} );
        $self->_executePluginAction( 'change' );
        $self->{'_data'}->{'plugin_config_prev'} = $self->{'_data'}->{'plugin_config'};
        $self->{'_data'}->{'plugin_info'}->{'__need_change__'} = JSON::false;
        $self->{'_dbh'}->do(
            'UPDATE plugin SET plugin_info = ?, plugin_config_prev = plugin_config WHERE plugin_id = ?',
            undef,
            encode_json( $self->{'_data'}->{'plugin_info'} ),
            $self->{'_data'}->{'pluginId'}
        );
        $self->{'eventManager'}->trigger( 'onAfterChangePlugin', $self->{'_data'}->{'plugin_name'} );
    }

    $self->_enable();
}

=item _run( )

 Run plugin item tasks

 Return void, die on failure

=cut

sub _run
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'onBeforeRunPlugin', $self->{'_data'}->{'plugin_name'} );
    $self->_executePluginAction( 'run' );
    $self->{'eventManager'}->trigger( 'onAfterRunPlugin', $self->{'_data'}->{'plugin_name'} );
}

=item _executePluginAction( $action )

 Execute the given plugin action

 Note that an exception that is raised in the context of the plugin run()
 action is ignored by default because it is normally the plugin responsability
 to update the entity for which the exception has been raised. However a plugin
 can force this module to bubble up the exception by setting the 'BUBBLE_EXCEPTIONS'
 property to a TRUE value, in which case the error will used to update the plugin
 status.

 Param string $action Action to execute on the plugin
 Return void, die on failure

=cut

sub _executePluginAction
{
    my ( $self, $action ) = @_;

    unless ( $self->{'_plugin_instances'}->{$self->{'_data'}->{'plugin_id'}} ) {
        local $SIG{'__WARN__'} = sub { die @_ }; # Turn any warning from plugin into exception

        my $pluginClass = iMSCP::Plugins->getInstance()->getClass( $self->{'_data'}->{'plugin_name'} );
        return unless $pluginClass->can( $action ); # Do not instantiate plugin when not necessary

        # A plugin must be either of type iMSCP::Common::Singleton or of type iMSCP::Common::Object
        $pluginClass->isa( 'iMSCP::Common::Singleton' ) xor $pluginClass->isa( 'iMSCP::Common::Object' ) or die(
            sprintf( 'The %s plugin must be either of type iMSCP::Common::Singleton or of type iMSCP::Common::Object' )
        );

        $self->{'_plugin_instances'}->{$self->{'_data'}->{'plugin_id'}} = (
            $pluginClass->can( 'getInstance' ) || $pluginClass->can( 'new' ) || die( 'Bad plugin class' )
        )->(
            $pluginClass,
            action       => $self->{'_data'}->{'plugin_action'},
            config       => $self->{'_data'}->{'plugin_config'},
            config_prev  => ( $self->{'_data'}->{'plugin_action'} =~ /^(?:change|update)$/
                # On plugin change/update, make sure that prev config also contains any new parameter
                ? merge( $self->{'_data'}->{'plugin_config_prev'}, $self->{'_data'}->{'plugin_config'} ) : $self->{'_data'}->{'plugin_config_prev'} ),
            eventManager => $self->{'eventManager'},
            info         => $self->{'_data'}->{'plugin_info'}
        );
    }

    my $subref = $self->{'_plugin_instances'}->{$self->{'_data'}->{'plugin_id'}}->can( $action ) or return;
    debug( sprintf( "Executing %s( ) action on %s", $action, ref $self->{'_plugin_instances'}->{$self->{'_data'}->{'plugin_id'}} ));

    local $@;
    eval {
        $subref->(
            $self->{'_plugin_instances'}->{$self->{'_data'}->{'plugin_id'}},
            ( $action eq 'update' ? ( $self->{'_data'}->{'plugin_info'}->{'version'}, $self->{'_data'}->{'plugin_info'}->{'__nversion__'} ) : () )
        );
    };

    # In context of the run() action, exception are not bubbled up by default, unless
    # the plugin 'BUBBLE_EXCEPTIONS' property is set with a TRUE value.
    die if $@ && ( $action ne 'run' || $self->{'_plugin_instances'}->{$self->{'_data'}->{'plugin_id'}}->{'BUBBLE_EXCEPTIONS'} );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
