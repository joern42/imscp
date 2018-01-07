=head1 NAME

 iMSCP::Servers::Cron::Vixie::Debian - i-MSCP (Debian) Vixie cron server implementation

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

package iMSCP::Servers::Cron::Vixie::Debian;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Class::Autouse qw/ :nostat iMSCP::Service /;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::TemplateParser qw/ processByRef replaceBlocByRef /;
use iMSCP::Umask;
use version;
use parent 'iMSCP::Servers::Cron';

=head1 DESCRIPTION

 i-MSCP (Debian) Vixie cron server implementation.
 
 See CRON(8) manpage.
 
=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ($self) = @_;

    my $rs = $self->buildConfFile( 'imscp', '/etc/cron.d/imscp', {},
        {
            QUOTA_ROOT_DIR  => $main::imscpConfig{'QUOTA_ROOT_DIR'},
            LOG_DIR         => $main::imscpConfig{'LOG_DIR'},
            TRAFF_ROOT_DIR  => $main::imscpConfig{'TRAFF_ROOT_DIR'},
            TOOLS_ROOT_DIR  => $main::imscpConfig{'TOOLS_ROOT_DIR'},
            BACKUP_MINUTE   => $main::imscpConfig{'BACKUP_MINUTE'},
            BACKUP_HOUR     => $main::imscpConfig{'BACKUP_HOUR'},
            BACKUP_ROOT_DIR => $main::imscpConfig{'BACKUP_ROOT_DIR'},
            CONF_DIR        => $main::imscpConfig{'CONF_DIR'},
            BACKUP_FILE_DIR => $main::imscpConfig{'BACKUP_FILE_DIR'}
        },
        { umask => 0027, mode => 0640 }
    );
    $rs ||= $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->enable( 'cron' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->SUPER::postinstall();
}

=item uninstall( )

 See iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ($self) = @_;

    return 0 unless -f '/etc/cron.d/imscp';

    iMSCP::File->new( filename => '/etc/cron.d/imscp' )->delFile();
}

=item setEnginePermissions( )

 See iMSCP::Servers::Abstract::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    return 0 unless -f '/etc/cron.d/imscp';

    setRights( '/etc/cron.d/imscp',
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0640'
        }
    );
}

=item getHumanizedServerName( )

 See iMSCP::Servers::Abstract::getHumanizedServerName()

=cut

sub getHumanizedServerName
{
    my ($self) = @_;

    'Cron (Vixie)';
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->start( 'cron' ); };
    if ( $@ ) {
        die( $@ );
        return 1;
    }

    0;
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->stop( 'cron' ); };
    if ( $@ ) {
        die( $@ );
        return 1;
    }

    0;
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->restart( 'cron' ); };
    if ( $@ ) {
        die( $@ );
        return 1;
    }

    0;
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->reload( 'cron' ); };
    if ( $@ ) {
        die( $@ );
        return 1;
    }

    0;
}

=item addTask( \%data [, $filepath = '/etc/cron.d/imscp' ] )

 See iMSCP::Servers::Cron::addTask()

=cut

sub addTask
{
    my ($self, $data, $filepath) = @_;
    $data = {} unless ref $data eq 'HASH';
    $filepath ||= '/etc/cron.d/imscp';

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

    $self->buildConfFile( $filepath, $filepath, {}, $data );
}

=item deleteTask( \%data [, $filepath = '/etc/cron.d/imscp' ] )

 See iMSCP::Servers::Cron::deleteTask()

=cut

sub deleteTask
{
    my ($self, $data, $filepath) = @_;
    $data = {} unless ref $data eq 'HASH';
    $filepath ||= '/etc/cron.d/imscp';

    unless ( exists $data->{'TASKID'} ) {
        error( 'Missing TASKID data' );
        return 1;
    }

    $self->buildConfFile( $filepath, $filepath, {}, $data );
}

=item enableSystemCronTask( $cronTask [, $directory = ALL ] )

 See iMSCP::Servers::Cron::enableSystemCronTask()

 We make use of dpkg-divert(1) because renaming the file without further
 treatment doesn't prevent the cron task to be reinstalled on package upgrade.

=cut

sub enableSystemCronTask
{
    my ($self, $cronTask, $directory) = @_;

    unless ( defined $cronTask ) {
        error( 'Undefined $cronTask parameter' );
        return 1;
    }

    unless ( $directory ) {
        for ( qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) {
            my $rs = execute( [ '/usr/bin/dpkg-divert', '--rename', '--remove', "/etc/$_/$cronTask" ], \my $stdout, \my $stderr );
            debug( $stdout ) if $stdout;
            error( $stderr || 'Unknown error' ) if $rs;
            return $rs if $rs;
        }

        return 0;
    }

    unless ( grep( $directory eq $_, qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) ) {
        error( 'Invalid cron directory' );
        return 1;
    }

    my $rs = execute( [ '/usr/bin/dpkg-divert', '--rename', '--remove', "/etc/$directory/$cronTask" ], \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;
}

=item disableSystemCronTask( $cronTask [, $directory = ALL ] )

 See iMSCP::Servers::Cron::disableSystemCrontask()

=cut

sub disableSystemCronTask
{
    my ($self, $cronTask, $directory) = @_;

    unless ( defined $cronTask ) {
        error( 'Undefined$cronTask parameter' );
        return 1;
    }

    unless ( $directory ) {
        for ( qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) {
            my $rs = execute(
                [ '/usr/bin/dpkg-divert', '--divert', "/etc/$_/$cronTask.disabled", '--rename', "/etc/$_/$cronTask" ], \my $stdout, \my $stderr
            );
            debug( $stdout ) if $stdout;
            error( $stderr || 'Unknown error' ) if $rs;
            return $rs if $rs;
        }

        return 0;
    }

    unless ( grep( $directory eq $_, qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) ) {
        error( 'Invalid cron directory' );
        return 1;
    }

    my $rs ||= execute(
        [ '/usr/bin/dpkg-divert', '--divert', "/etc/$directory/$cronTask.disabled", '--rename', "/etc/$directory/$cronTask" ],
        \my $stdout,
        \my $stderr
    );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    $rs;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init()

 Initialize instance

 Return iMSCP::Servers::Cron::Vixie::Debian

=cut

sub _init
{
    my ($self) = @_;

    # Register required event listener for processing of cron tasks
    $self->{'eventManager'}->register( 'beforeCronBuildConfFile', $self );
    $self->SUPER::_init();
}

=item _cleanup

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    return 0 unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' ) && -f '/etc/imscp/cron/cron.data';

    iMSCP::File->new( filename => '/etc/imscp/cron/cron.data' )->delFile();
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
 Param hashref \%mdata OPTIONAL Data as provided by i-MSCP modules
 Param hashref \%sdata OPTIONAL Server data (Server data have higher precedence than modules data)
 Param hashref \%sconfig Cron server configuration
 Param hashref \%params OPTIONAL parameters:
  - umask : UMASK(2) for a new file. For instance if the given umask is 0027, mode will be: 0666 & (~0027) = 0640 (in octal), default to umask()
  - user  : File owner (default: root)
  - group : File group (default: root
  - mode  : File mode (default: 0644)
  - cached : Whether or not loaded file must be cached in memory

=cut

sub beforeCronBuildConfFile
{
    my ($cronServer, \$cfgTpl, $filename, \$trgFile, $mdata, $sdata, $sconfig, $params) = @_;

    # Return early if that event listener has not been triggered in the context of the ::addTask() or ::deleteTask() actions.
    return 0 unless exists $sdata->{'TASKID'};

    # Make sure that entry is not added twice
    replaceBlocByRef( qr/^\s*\Q# imscp [$sdata->{'TASKID'}] entry BEGIN\E\n/m, qr/\Q# imscp [$sdata->{'TASKID'}] entry ENDING\E\n/, '', $cfgTpl );

    # Return early if that event listener has not been triggered in the context of the ::addTask() action.
    return 0 unless exists $sdata->{'COMMAND'};

    ( ${$cfgTpl} .= <<"EOF" ) =~ s/^(\@[^\s]+)\s+/$1 /gm;

# imscp [$data->{'TASKID'}] entry BEGIN
$sdata->{'MINUTE'} $sdata->{'HOUR'} $sdata->{'DAY'} $data->{'MONTH'} $sdata->{'DWEEK'} $sdata->{'USER'} $sdata->{'COMMAND'}
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
