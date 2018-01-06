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

    my $file = iMSCP::File->new( filename => '/etc/imscp/cron/imscp' );
    $fileContentRef = $file->getAsRef();
    unless ( defined $fileContentRef ) {
        error( sprintf( "Couldn't read the %s file", '/etc/imscp/cron/imscp' ));
        return 1;
    }

    processByRef(
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
        $fileContentRef
    );

    local $UMASK = 027;
    $file->{'fileName'} = '/etc/cron.d/imscp';
    $rs = $file->save();
    $rs ||= $file->owner( $main::imscpConfig{'ROOT_USER'}, $main::imscpConfig{'ROOT_GROUP'} );
    $rs ||= $file->mode( 0640 );
    $rs || $self->_cleanup();
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

    return 0 unless -f '/etc/imscp/cron.d/imscp';

    iMSCP::File->new( filename => '/etc/imscp/cron.d/imscp' )->delFile();
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

    unless ( exists $data->{'COMMAND'} && exists $data->{'TASKID'} ) {
        error( 'Missing command or task ID' );
        return 1;
    }

    $filepath ||= '/etc/cron.d/imscp';

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

    my $file = iMSCP::File->new( filename => $filepath );
    my $fileContentRef = \ '';

    if ( -f $filepath ) {
        $fileContentRef = $file->getAsRef();
        unless ( defined $fileContentRef ) {
            error( sprintf( "Couldn't read the %s file", $file->{'filename'} ));
            return 1;
        }

        # Remove entry with same ID if any
        replaceBlocByRef(
            qr/^\s*\Q# imscp [$data->{'TASKID'}] entry BEGIN\E\n/m, qr/\Q# imscp [$data->{'TASKID'}] entry ENDING\E\n/, '', $fileContentRef
        );
    } else {
        ${$fileContentRef} = <<'EOF';
# CRON(8) configuration file - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

EOF
    }

    my $rs = $self->{'eventManager'}->trigger( 'beforeCronAddTask', $fileContentRef, $data );
    return $rs if $rs;

    ( ${$fileContentRef} .= <<"EOF" ) =~ s/^(\@[^\s]+)\s+/$1 /gm;

# imscp [$data->{'TASKID'}] entry BEGIN
$data->{'MINUTE'} $data->{'HOUR'} $data->{'DAY'} $data->{'MONTH'} $data->{'DWEEK'} $data->{'USER'} $data->{'COMMAND'}
# imscp [$data->{'TASKID'}] entry ENDING
EOF

    $rs = $self->{'eventManager'}->trigger( 'afterCronAddTask', $fileContentRef, $data );
    $rs ||= $file->save();
}

=item deleteTask( \%data [, $filepath = '/etc/cron.d/imscp' ] )

 See iMSCP::Servers::Cron::deleteTask()

=cut

sub deleteTask
{
    my ($self, $data, $filepath) = @_;
    $data = {} unless ref $data eq 'HASH';

    unless ( exists $data->{'TASKID'} ) {
        error( 'Missing task ID' );
        return 1;
    }

    $filepath ||= '/etc/cron.d/imscp';
    return 0 unless -f $filepath;

    my $file = iMSCP::File->new( filename => $filepath );
    my $fileContentRef = $file->getAsRef();
    unless ( defined $fileContentRef ) {
        error( sprintf( "Couldn't read the %s file", $file->{'filename'} ));
        return 1;
    }

    my $rs = $self->{'eventManager'}->trigger( 'beforeCronDeleteTask', $fileContentRef, $data );
    return $rs if $rs;

    replaceBlocByRef(
        qr/^\s*\Q# imscp [$data->{'TASKID'}] entry BEGIN\E\n/m, qr/\Q# imscp [$data->{'TASKID'}] entry ENDING\E\n/, '', $fileContentRef
    );

    $rs = $self->{'eventManager'}->trigger( 'afterCronDeleteTask', $fileContentRef, $data );
    $rs ||= $file->save();
}

=item enableSystemCronTask( $cronTask [, $directory = ALL ] )

 See iMSCP::Servers::Cron::enableSystemCronTask()

=cut

sub enableSystemCronTask
{
    my ($self, $crontask, $directory) = @_;

    unless ( defined $crontask ) {
        error( 'Undefined $crontask parameter' );
        return 1;
    }

    unless ( $directory ) {
        for ( qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) {
            my $rs = execute( [ '/usr/bin/dpkg-divert', '--rename', '--remove', "/etc/$_/$crontask" ], \my $stdout, \my $stderr );
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

    my $rs = execute( [ '/usr/bin/dpkg-divert', '--rename', '--remove', "/etc/$directory/$crontask" ], \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;
}

=item disableSystemCrontask( $cronTask [, $directory = ALL ] )

 See iMSCP::Servers::Cron::disableSystemCrontask()

=cut

sub disableSystemCrontask
{
    my ($self, $crontask, $directory) = @_;

    unless ( defined $crontask ) {
        error( 'Undefined $crontask parameter' );
        return 1;
    }

    unless ( $directory ) {
        for ( qw/ cron.d cron.hourly cron.daily cron.weekly cron.monthly / ) {
            my $rs = execute(
                [ '/usr/bin/dpkg-divert', '--divert', "/etc/$_/$crontask.disabled", '--rename', "/etc/$_/$crontask" ], \my $stdout, \my $stderr
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
        [ '/usr/bin/dpkg-divert', '--divert', "/etc/$directory/$crontask.disabled", '--rename', "/etc/$directory/$crontask" ],
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

=item _cleanup

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    return 0 unless -f '/etc/imscp/cron/cron.data';

    iMSCP::File->new( filename => '/etc/imscp/cron/cron.data' )->delFile();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
