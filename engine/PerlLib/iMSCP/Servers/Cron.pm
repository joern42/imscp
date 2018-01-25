=head1 NAME

 iMSCP::Servers::Cron - Factory and abstract implementation for the i-MSCP cron servers

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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

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
    my ($self) = @_;

    my $rs = $self->_setVersion();
    $rs ||= $self->buildConfFile( 'imscp', "$self->{'config'}->{'CRON_D_DIR'}/imscp", undef,
        {
            QUOTA_ROOT_DIR  => $main::imscpConfig{'QUOTA_ROOT_DIR'},
            LOG_DIR         => $main::imscpConfig{'LOG_DIR'},
            TRAFF_ROOT_DIR  => $main::imscpConfig{'TRAFF_ROOT_DIR'},
            TOOLS_ROOT_DIR  => $main::imscpConfig{'TOOLS_ROOT_DIR'},
            CONF_DIR        => $main::imscpConfig{'CONF_DIR'},
            BACKUP_FILE_DIR => $main::imscpConfig{'BACKUP_FILE_DIR'}
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
    my ($self) = @_;

    return 0 unless -f "$self->{'config'}->{'CRON_D_DIR'}/imscp";

    iMSCP::File->new( filename => "$self->{'config'}->{'CRON_D_DIR'}/imscp" )->delFile();
}

=item setEnginePermissions( )

 See iMSCP::Servers::Abstract::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    return 0 unless -f "$self->{'config'}->{'CRON_D_DIR'}/imscp";

    setRights( "$self->{'config'}->{'CRON_D_DIR'}/imscp",
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0640'
        }
    );
}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ($self) = @_;

    'Cron';
}

=item getVersion( )

 See iMSCP::Servers::Abstract::getVersion()

=cut

sub getVersion
{
    my ($self) = @_;

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
  Return int 0 on success, other on failure

=cut

sub addTask
{
    my ($self, $data, $filepath) = @_;
    $data = {} unless ref $data eq 'HASH';
    $filepath //= "$self->{'config'}->{'CRON_D_DIR'}/imscp";

    unless ( exists $data->{'COMMAND'} && exists $data->{'TASKID'} ) {
        error( 'Missing COMMAND or TASKID data' );
        return 1;
    }

    $data->{'MINUTE'} //= '@daily';
    $data->{'HOUR'} //= '*';
    $data->{'DAY'} //= '*';
    $data->{'MONTH'} //= '*';
    $data->{'DWEEK'} //= '*';
    $data->{'USER'} //= $main::imscpConfig{'ROOT_USER'};

    eval { $self->_validateCronTask( $data ); };
    if ( $@ ) {
        error( sprintf( 'Invalid cron tasks: %s', $@ ));
        return 1;
    }

    $self->buildConfFile( $filepath, $filepath, undef, $data );
}

=item deleteTask( \%data [, $filepath = "$self->{'config'}->{'CRON_D_DIR'}/imscp" ] )

 Delete a cron task

 Param hashref \%data Cron task data:
  - TASKID Cron task unique identifier
 Param string $filepath OPTIONAL Cron file path, default to i-MSCP master cron file.
 Return int 0 on success, other on failure

=cut

sub deleteTask
{
    my ($self, $data, $filepath) = @_;
    $data = {} unless ref $data eq 'HASH';
    $filepath //= "$self->{'config'}->{'CRON_D_DIR'}/imscp";

    unless ( exists $data->{'TASKID'} ) {
        error( 'Missing TASKID data' );
        return 1;
    }

    $self->buildConfFile( $filepath, $filepath, undef, $data );
}

=item enableSystemCronTask( $cronTask [, $directory = ALL ] )

 Enables a system cron task, that is, a cron task provided by a distribution package

 Param string $cronTask Cron task name
 Param string $directory OPTIONAL Directory on which operate on (cron.d,cron.hourly,cron.daily,cron.weekly,cron.monthly), default all
 Return int 0 on success, other on failure

=cut

sub enableSystemCronTask
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the enableSystemCronTask() method', ref $self ));
}

=item disableSystemCronTask( $cronTask [, $directory = ALL ] )

 Disables a system cron task, that is, a cron task provided by a distribution package that has been previously disabled
 
 Param string $cronTask Cron task name
 Param string $directory OPTIONAL Directory on which operate on (cron.d,cron.hourly,cron.daily,cron.weekly,cron.monthly), default all
 Return int 0 on success, other on failure

=cut

sub disableSystemCronTask
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the disableSystemCronTask() method', ref $self ));
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Servers::Abstract::_init()

=cut

sub _init
{
    my ($self) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    @{$self}{qw/ cfgDir _templates /} = ( "$main::imscpConfig{'CONF_DIR'}/cron", {} );
    $self->{'eventManager'}->register( 'beforeCronBuildConfFile', $self );
    $self->SUPER::_init();
}

=item _setVersion( )

 Set Cron version

 Return int 0 on success, other on failure

=cut

sub _setVersion
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the _setVersion() method', ref $self ));
}

=item _validateCronTask( \%data )

 Validate cron task fields

 Param hashref \%data Cron data
 Return void, croak if a field isn't valid

=cut

sub _validateCronTask
{
    my ($self, $data) = @_;

    if ( grep( $data->{'MINUTE'} eq $_, qw/ @reboot @yearly @annually @monthly @weekly @daily @midnight @hourly / ) ) {
        $data->{'HOUR'} = $data->{'DAY'} = $data->{'MONTH'} = $data->{'DWEEK'} = '';
        return;
    }

    $self->_validateField( $_, $data->{ $_ } ) for qw/ MINUTE HOUR DAY MONTH DWEEK /;
}

=item _validateField( $name, $value )

 Validate the given cron task field

 Param string $name Fieldname (uppercase)
 Param string $value Fieldvalue
 Return void, croak if the given field isn't valid

=cut

sub _validateField
{
    my (undef, $name, $value) = @_;

    defined $name or croak( '$name is undefined' );
    defined $value or croak( '$value is undefined' );
    $value ne '' or croak( sprintf( "Value for the '%s' cron task field cannot be empty", $name ));
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

        my ($left) = grep { $namesArr[$_] eq lc( $compare[0] ) } 0 .. $#namesArr;
        my ($right) = grep { $namesArr[$_] eq lc( $compare[1] ) } 0 .. $#namesArr;

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
  - umask   : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & (~0027) = 0640 (in octal), default to UMASK(2)
  - user    : File owner (default: $> (EUID) for a new file, no change for existent file)
  - group   : File group (default: $) (EGID) for a new file, no change for existent file)
  - mode    : File mode (default: 0666 & (~UMASK(2)) for a new file, no change for existent file )
  - cached  : Whether or not loaded file must be cached in memory
  - srcname : Make it possible to override default source filename passed into event listeners. Most used when $srcFile is a TMPFILE(3) file
=cut

sub beforeCronBuildConfFile
{
    my ($cronServer, $cfgTpl, $filename, $trgFile, $mdata, $sdata, $sconfig, $params) = @_;

    # Return early if that event listener has not been triggered in the context of the ::addTask() or ::deleteTask() actions.
    return 0 unless exists $sdata->{'TASKID'};

    # Make sure that entry is not added twice in the context of the ::addTask() action.
    # Delete the cron task in context of the ::deleteTask() action.
    replaceBlocByRef( qr/^\s*\Q# imscp [$sdata->{'TASKID'}] entry BEGIN\E\n/m, qr/\Q# imscp [$sdata->{'TASKID'}] entry ENDING\E\n/, '', $cfgTpl );

    # Return early if that event listener has not been triggered in the context of the ::addTask() action.
    return 0 unless exists $sdata->{'COMMAND'};

    ( ${$cfgTpl} .= <<"EOF" ) =~ s/^(\@[^\s]+)\s+/$1 /gm;

# imscp [$sdata->{'TASKID'}] entry BEGIN
$sdata->{'MINUTE'} $sdata->{'HOUR'} $sdata->{'DAY'} $sdata->{'MONTH'} $sdata->{'DWEEK'} $sdata->{'USER'} $sdata->{'COMMAND'}
# imscp [$sdata->{'TASKID'}] entry ENDING
EOF
    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
