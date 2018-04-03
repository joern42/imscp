=head1 NAME

 iMSCP::Servers::Cron - Factory and abstract implementation for the i-MSCP cron servers

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

package iMSCP::Servers::Cron;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Carp qw/ croak /;
use iMSCP::Debug qw/ error /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::TemplateParser qw/ replaceBlocByRef /;
use parent 'iMSCP::Servers::Abstract';

=head1 DESCRIPTION

 This class provides a factory and an abstract implementation for the i-MSCP cron servers.

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_setVersion();
    $self->buildConfFile( 'imscp', "$self->{'config'}->{'CRON_D_DIR'}/imscp", undef,
        {
            QUOTA_ROOT_DIR  => "$::imscpConfig{'BACKEND_ROOT_DIR'}/quota",
            LOG_DIR         => $::imscpConfig{'LOG_DIR'},
            TRAFF_ROOT_DIR  => "$::imscpConfig{'BACKEND_ROOT_DIR'}/traffic",
            TOOLS_ROOT_DIR  => "$::imscpConfig{'BACKEND_ROOT_DIR'}/tools",
            CONF_DIR        => $::imscpConfig{'CONF_DIR'},
            BACKUP_FILE_DIR => "$::imscpConfig{'ROOT_DIR'}/backups"
        },
        {
            umask => 0027,
            mode  => 0640
        }
    );
}

=item uninstall( )

 See iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    iMSCP::File->new( filename => "$self->{'config'}->{'CRON_D_DIR'}/imscp" )->remove();
}

=item setBackendPermissions( )

 See iMSCP::Servers::Abstract::setBackendPermissions()

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;

    return unless -f "$self->{'config'}->{'CRON_D_DIR'}/imscp";

    setRights( "$self->{'config'}->{'CRON_D_DIR'}/imscp", {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'},
        mode  => '0640'
    } );
}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ( $self ) = @_;

    'Cron';
}

=item getServerVersion( )

 See iMSCP::Servers::Abstract::getServerVersion()

=cut

sub getServerVersion
{
    my ( $self ) = @_;

    $self->{'config'}->{'CRON_VERSION'};
}

=item addTask( \%data [, $filepath = "$self->{'config'}->{'CRON_D_DIR'}/imscp" ] )

 Add a new cron task

 Param hashref \%data Cron task data:
  - TASKID :Cron task unique identifier
  - MINUTE  : OPTIONAL Minute or shortcut such as @daily, @monthly... (Default: @daily)
  - HOUR    : OPTIONAL Hour - ignored if the MINUTE field defines a shortcut (Default: *)
  - DAY     : OPTIONAL Day of month - ignored if the MINUTE field defines a shortcut (Default: *)
  - MONTH   : OPTIONAL Month - ignored if the MINUTE field defines a shortcut - Default (Default: *)
  - DWEEK   : OPTIONAL Day of week - ignored if the MINUTE field defines a shortcut - (Default: *)
  - USER    : OPTIONAL Use under which the command must be run (default: root)
  - COMMAND : Command to run
  Param string $filepath OPTIONAL Cron file path, default to i-MSCP master cron file. If provided, $filepath must exist.
  Return void, die on failure

=cut

sub addTask
{
    my ( $self, $data, $filepath ) = @_;
    $data = {} unless ref $data eq 'HASH';
    $filepath //= "$self->{'config'}->{'CRON_D_DIR'}/imscp";

    exists $data->{'COMMAND'} && exists $data->{'TASKID'} or croak( 'Missing COMMAND or TASKID data' );

    $data->{'MINUTE'} //= '@daily';
    $data->{'HOUR'} //= '*';
    $data->{'DAY'} //= '*';
    $data->{'MONTH'} //= '*';
    $data->{'DWEEK'} //= '*';
    $data->{'USER'} //= $::imscpConfig{'ROOT_USER'};

    $self->_validateCronTask( $data );
    $self->buildConfFile( $filepath, undef, undef, $data );
}

=item deleteTask( \%data [, $filepath = "$self->{'config'}->{'CRON_D_DIR'}/imscp" ] )

 Delete a cron task

 Param hashref \%data Cron task data:
  - TASKID Cron task unique identifier
 Param string $filepath OPTIONAL Cron file path, default to i-MSCP master cron file.
 Return void, die on failure

=cut

sub deleteTask
{
    my ( $self, $data, $filepath ) = @_;
    $data = {} unless ref $data eq 'HASH';
    $filepath //= "$self->{'config'}->{'CRON_D_DIR'}/imscp";

    exists $data->{'TASKID'} or croak( 'Missing TASKID data' );
    $self->buildConfFile( $filepath, undef, undef, $data );
}

=item enableSystemTask( $cronTask [, $directory = ALL ] )

 Enables a system cron task, that is, a cron task provided by a distribution package

 Param string $cronTask Cron task name
 Param string $directory OPTIONAL Directory on which operate on (cron.d,cron.hourly,cron.daily,cron.weekly,cron.monthly), default all
 Return void, die on failure

=cut

sub enableSystemTask
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the enableSystemTask() method', ref $self ));
}

=item disableSystemTask( $cronTask [, $directory = ALL ] )

 Disables a system cron task, that is, a cron task provided by a distribution package that has been previously disabled
 
 Param string $cronTask Cron task name
 Param string $directory OPTIONAL Directory on which operate on (cron.d,cron.hourly,cron.daily,cron.weekly,cron.monthly), default all
 Return void, die on failure

=cut

sub disableSystemTask
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the disableSystemTask() method', ref $self ));
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Servers::Abstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    @{ $self }{qw/ cfgDir _templates /} = ( "$::imscpConfig{'CONF_DIR'}/cron", {} );
    $self->{'eventManager'}->register( 'beforeCronBuildConfFile', $self );
    $self->SUPER::_init();
}

=item _setVersion( )

 Set Cron version

 Return void, die on failure

=cut

sub _setVersion
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the _setVersion() method', ref $self ));
}

=item _validateCronTask( \%data )

 Validate cron task fields

 Param hashref \%data Cron data
 Return void, croak if a field isn't valid

=cut

sub _validateCronTask
{
    my ( $self, $data ) = @_;

    if ( grep ( $data->{'MINUTE'} eq $_, qw/ @reboot @yearly @annually @monthly @weekly @daily @midnight @hourly / ) ) {
        $data->{'HOUR'} = $data->{'DAY'} = $data->{'MONTH'} = $data->{'DWEEK'} = '';
        return;
    }

    $self->_validateField( $_, $data->{ $_ } ) for qw/ MINUTE HOUR DAY MONTH DWEEK /;
}

=item _validateField( $name, $value )

 Validate the given cron task field

 Param string $name Fieldname (uppercase)
 Param string $value Fieldvalue
 Return void, croak if the field isn't valid

=cut

sub _validateField
{
    my ( undef, $name, $value ) = @_;

    defined $name or croak( '$name is undefined' );
    length $value or croak( sprintf( "Value for the '%s' cron task field cannot be empty", $name ));
    return if $value eq '*';

    my $step = '[1-9]?[0-9]';
    my $months = 'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec';
    my $days = 'mon|tue|wed|thu|fri|sat|sun';
    my @namesArr = ();
    my $pattern;

    if ( $name eq 'MINUTE' ) {
        $pattern = '[ ]*(\b[0-5]?[0-9]\b)[ ]*';
    } elsif ( $name eq 'HOUR' ) {
        $pattern = '[ ]*(\b[01]?[0-9]\b|\b2[0-3]\b)[ ]*';
    } elsif ( $name eq 'DAY' ) {
        $pattern = '[ ]*(\b[01]?[1-9]\b|\b2[0-9]\b|\b3[01]\b)[ ]*';
    } elsif ( $name eq 'MONTH' ) {
        @namesArr = split '|', $months;
        $pattern = "([ ]*(\b[0-1]?[0-9]\b)[ ]*)|([ ]*($months)[ ]*)";
    } elsif ( $name eq 'DWEEK' ) {
        @namesArr = split '|', $days;
        $pattern = "([ ]*(\b[0]?[0-7]\b)[ ]*)|([ ]*($days)[ ]*)";
    }

    defined $pattern or croak( sprintf( "Unknown '%s' cron task field", $name ));

    my $range = "((($pattern)|(\\*\\/$step)?)|((($pattern)-($pattern))(\\/$step)?))";
    my $longPattern = "$range(,$range)*";

    $value =~ /^$longPattern$/i or croak( sprintf( "Invalid value '%s' given for the '%s' cron task field", $value, $name ));

    for ( split ',', $value ) {
        next unless /^(?:(?:(?:$pattern)-(?:$pattern))(?:\/$step)?)+$/;

        my @compare = split '-';
        my @compareSlash = split '/', $compare['1'];

        $compare[1] = $compareSlash[0] if scalar @compareSlash == 2;

        my ( $left ) = grep { $namesArr[$_] eq lc( $compare[0] ) } 0 .. $#namesArr;
        my ( $right ) = grep { $namesArr[$_] eq lc( $compare[1] ) } 0 .. $#namesArr;

        $left = $compare[0] unless $left;
        $right = $compare[1] unless $right;

        if ( int( $left ) > int( $right ) ) {
            croak( sprintf( "Invalid value '%s' given for the '%s' cron task field", $value, $name ));
        }
    }
}

=back

=head1 EVENT LISTENERS

=over 4

=item beforeCronBuildConfFile( $cronServer, \$cfgTpl, $filename, \$trgFile, $mdata, $sdata, $sconfig, $params )

 Event listener that listen on the beforeCronBuildConfFile to process cron tasks

 Param iMSCP::Servers::Cron::Vixie::Debian $cronServer Cron server instance
 Param scalar \$cfgTpl Reference to cron file content
 Param string $filename Cron file name
 Param string $trgFile Target file path
 Param hashref \%mdata OPTIONAL Data as provided by the iMSCP::Modules::* modules, none if called outside of an i-MSCP module context
 Param hashref \%sdata OPTIONAL Server data (Server data have higher precedence than modules data)
 Param hashref \%sconfig Cron server configuration
 Param hashref \%params OPTIONAL parameters:
  - umask   : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & ~0027 = 0640 (in octal)
  - user    : File owner (default: EUID for a new file, no change for existent file)
  - group   : File group (default: EGID for a new file, no change for existent file)
  - mode    : File mode (default: 0666 & ~(UMASK(2) || 0) for a new file, no change for existent file )
  - cached  : Whether or not loaded file must be cached in memory
  - srcname : Make it possible to override default source filename passed into event listeners. Most used when $srcFile is a TMPFILE(3) file
  Return void, die on failure
=cut

sub beforeCronBuildConfFile
{
    my ( $cronServer, $cfgTpl, $filename, $trgFile, $mdata, $sdata, $sconfig, $params ) = @_;

    # Return early if that event listener has not been triggered in the context of the ::addTask() or ::deleteTask() actions.
    return unless exists $sdata->{'TASKID'};

    # Make sure that entry is not added twice in the context of the ::addTask() action.
    # Delete the cron task in context of the ::deleteTask() action.
    replaceBlocByRef( qr/^\s*\Q# imscp [$sdata->{'TASKID'}] entry BEGIN\E\n/m, qr/\Q# imscp [$sdata->{'TASKID'}] entry ENDING\E\n/, '', $cfgTpl );

    # Return early if that event listener has not been triggered in the context of the ::addTask() action.
    return unless exists $sdata->{'COMMAND'};

    ( ${ $cfgTpl } .= <<"EOF" ) =~ s/^(\@[^\s]+)\s+/$1 /gm;

# imscp [$sdata->{'TASKID'}] entry BEGIN
$sdata->{'MINUTE'} $sdata->{'HOUR'} $sdata->{'DAY'} $sdata->{'MONTH'} $sdata->{'DWEEK'} $sdata->{'USER'} $sdata->{'COMMAND'}
# imscp [$sdata->{'TASKID'}] entry ENDING
EOF
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
