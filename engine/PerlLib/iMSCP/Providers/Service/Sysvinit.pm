=head1 NAME

 iMSCP::Providers::Service::Sysvinit - SysVinit base service provider implementation

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

package iMSCP::Providers::Service::Sysvinit;

use strict;
use warnings;
use Carp qw/ croak /;
use File::Spec;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use parent qw/ iMSCP::Common::Singleton iMSCP::Providers::Service::Interface /;

my $EXEC_OUTPUT;

=head1 DESCRIPTION

 SysVinit base service provider implementation.

=head1 PUBLIC METHODS

=over 4

=item remove( $service )

 See iMSCP::Providers::Service::Interface

=cut

sub remove
{
    my ($self, $service) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    if ( my $initScriptPath = eval { $self->getInitScriptPath( $service, 'nocache' ); } ) {
        return 0 if iMSCP::File->new( filename => $initScriptPath )->delFile();
    }

    1;
}

=item start( $service )

 See iMSCP::Providers::Service::Interface

=cut

sub start
{
    my ($self, $service) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    return 1 if $self->isRunning( $service );

    $self->_exec( [ $self->getInitScriptPath( $service ), 'start' ] ) == 0;
}

=item stop( $service )

 See iMSCP::Providers::Service::Interface

=cut

sub stop
{
    my ($self, $service) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    return 1 unless $self->isRunning( $service );

    $self->_exec( [ $self->getInitScriptPath( $service ), 'stop' ] ) == 0;
}

=item restart( $service )

 See iMSCP::Providers::Service::Interface

=cut

sub restart
{
    my ($self, $service) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    return $self->_exec( [ $self->getInitScriptPath( $service ), 'restart' ] ) == 0 if $self->isRunning( $service );

    $self->_exec( [ $self->getInitScriptPath( $service ), 'start' ] ) == 0;
}

=item reload( $service )

 See iMSCP::Providers::Service::Interface

=cut

sub reload
{
    my ($self, $service) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    if ( $self->isRunning( $service ) ) {
        # We need catch STDERR here as we do do want report it as error
        my $ret = $self->_exec( [ $self->getInitScriptPath( $service ), 'reload' ], undef, \ my $stderr ) == 0;
        return $self->restart( $service ) unless $ret; # Reload failed. Try a restart instead.
        return $ret;
    }

    $self->_exec( [ $self->getInitScriptPath( $service ), 'start' ] ) == 0;
}

=item isRunning( $service )

 See iMSCP::Providers::Service::Interface

=cut

sub isRunning
{
    my ($self, $service) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    return $self->_exec( [ $self->getInitScriptPath( $service ), 'status' ] ) == 0 unless defined $self->{'_pid_pattern'};

    my $ret = $self->_getPid( $self->{'_pid_pattern'} );
    $self->{'_pid_pattern'} = undef;
    $ret;
}

=item hasService( $service )

 See iMSCP::Providers::Service::Interface

=cut

sub hasService
{
    my ($self, $service) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    eval { $self->_searchInitScript( $service ); };
}

=item getInitScriptPath( $service, [ $nocache =  FALSE ] )

 Get full path of the SysVinit script that belongs to the given service

 Param string $service Service name
 Param bool $nocache OPTIONAL If true, no cache will be used
 Return string Init script path on success, croak on failure

=cut

sub getInitScriptPath
{
    my ($self, $service, $nocache) = @_;

    defined $service or croak( 'Missing or undefined $service parameter' );

    $self->_searchInitScript( $service, $nocache );
}

=item setPidPattern( $pattern )

 Set PID pattern for next _getPid( ) invocation

 Param string|Regexp $pattern Process PID pattern
 Return int 0

=cut

sub setPidPattern
{
    my ($self, $pattern) = @_;

    defined $pattern or croak( 'Missing or undefined $pattern parameter' );

    $self->{'_pid_pattern'} = ref $pattern eq 'Regexp' ? $pattern : qr/$pattern/;
    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Providers::Service::Sysvinit, croak on failure

=cut

sub _init
{
    my ($self) = @_;

    exists $main::imscpConfig{'DISTRO_FAMILY'} or croak( 'You must first bootstrap the i-MSCP backend' );

    if ( $main::imscpConfig{'DISTRO_FAMILY'} =~ /^(?:FreeBSD|DragonFly)$/ ) {
        $self->{'sysvinitscriptpaths'} = [ '/etc/rc.d', '/usr/local/etc/rc.d' ];
    } elsif ( $main::imscpConfig{'DISTRO_FAMILY'} eq 'HP-UX' ) {
        $self->{'sysvinitscriptpaths'} = [ '/sbin/init.d' ];
    } elsif ( $main::imscpConfig{'DISTRO_FAMILY'} eq 'Archlinux' ) {
        $self->{'sysvinitscriptpaths'} = [ '/etc/rc.d' ];
    } else {
        $self->{'sysvinitscriptpaths'} = [ '/etc/init.d' ];
    }

    $self;
}

=item _isSysvinit( $service )

 Does the given service is managed by a SysVinit script?

 Param string $service Service name
 Return bool TRUE if the given service is managed by a SysVinit script, FALSE otherwise

=cut

sub _isSysvinit
{
    my ($self, $service) = @_;

    eval { $self->_searchInitScript( $service ); };
}

=item searchInitScript( $service, [ $nocache =  FALSE ] )

 Search the SysVinit script that belongs to the given service in all available paths

 Param string $service Service name
 Param bool $nocache OPTIONAL If true, no cache will be used
 Return string Init script path on success, croak on failure

=cut

sub _searchInitScript
{
    my ($self, $service, $nocache) = @_;

    # Make sure that init scrips are searched once
    CORE::state %initScripts;

    if ( $nocache ) {
        delete $initScripts{$service};
    } elsif ( exists $initScripts{$service} ) {
        defined $initScripts{$service} or croak( sprintf( "SysVinit script %s not found", $service ));
        return $initScripts{$service};
    }

    for ( @{$self->{'sysvinitscriptpaths'}} ) {
        my $initScriptPath = File::Spec->join( $_, $service );
        $initScripts{$service} = $initScriptPath if -f $initScriptPath;
        last if $initScripts{$service};

        $initScriptPath .= '.sh';
        $initScripts{$service} = $initScriptPath if -f $initScriptPath;
    }

    unless ( $nocache || $initScripts{$service} ) {
        $initScripts{$service} = undef;
    }

    $initScripts{$service} or croak( sprintf( "SysVinit script %s not found", $service ));
    $nocache ? delete $initScripts{$service} : $initScripts{$service};
}

=item _exec( \@command, [ \$stdout [, \$stderr ]] )

 Execute the given command

 It is possible to capture both STDOUT and STDERR output by providing scalar
 references. STDERR output is used for error reporting when the command status
 is other than 0 and if no scalar reference has been provided for its capture.

 Param array_ref \@command Command to execute
 Param scalar_ref \$stdout OPTIONAL Scalar reference for STDOUT capture
 Param scalar_ref \$stderr OPTIONAL Scalar reference for STDERR capture
 Return int Command exit status

=cut

sub _exec
{
    my (undef, $command, $stdout, $stderr) = @_;

    my $ret = execute( $command, ref $stdout eq 'SCALAR' ? $stdout : \$stdout, ref $stderr eq 'SCALAR' ? $stderr : \ $stderr );
    ref $stdout ? ${$stdout} eq '' || debug( ${$stdout} ) : $stdout eq '' || debug( $stdout );
    #ref $stderr ? ${$stderr} eq '' || debug( ${$stderr} ) : $stderr eq '' || debug( $stderr ) unless $ret;
    ref $stderr ? ${$stderr} eq '' || error( ${$stderr} ) : $stderr eq '' || error( $stderr ) if $ret && ref $stderr ne 'SCALAR';

    $EXEC_OUTPUT = \ ( ref $stdout ? ${$stdout} : $stdout );
    $ret;
}

=item _getLastExecOutput()

 Get output of last exec command

 return string Command STDOUT

=cut

sub _getLastExecOutput
{
    my ($self) = @_;

    ${$EXEC_OUTPUT};
}

=item _getPs( )

 Get proper 'ps' invocation for the platform

 Return int Command exit status

=cut

sub _getPs
{
    if ( $main::imscpConfig{'DISTRO_FAMILY'} eq 'OpenWrt' ) {
        'ps www';
    } elsif ( grep( $main::imscpConfig{'DISTRO_FAMILY'} eq $_, qw/ FreeBSD NetBSD OpenBSD Darwin DragonFly / ) ) {
        'ps auxwww';
    } else {
        'ps -ef'
    }
}

=item _getPid( $pattern )

 Get the process ID for a running process

 Param Regexp $pattern PID pattern
 Return int|undef Process ID or undef if not found

=cut

sub _getPid
{
    my ($self, $pattern) = @_;

    defined $pattern or croak( 'Missing or undefined $pattern parameter' );

    my $ps = $self->_getPs();
    open my $fh, '-|', $ps or croak( sprintf( "Couldn't pipe to %s: %s", $ps, $! ));

    while ( <$fh> ) {
        next unless /$pattern/;
        return ( split /\s+/, s/^\s+//r )[1];
    }

    undef;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
