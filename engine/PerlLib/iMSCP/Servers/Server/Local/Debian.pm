=head1 NAME

 iMSCP::Servers::Server::Local::Debian - i-MSCP (Debian) Local server implementation

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

package iMSCP::Servers::Server::Local::Debian;

use strict;
use warnings;
use autouse 'iMSCP::Debug' => qw/ debug error /;
use Class::Autouse qw/ :nostat iMSCP::Bootstrapper iMSCP::File iMSCP::ProgramFinder /;
use iMSCP::Service;
use JSON qw/ decode_json /;
use parent 'iMSCP::Servers::Server::Local::Abstract';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Local server implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Servers::Local::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->SUPER::install();
    $self->_cleanup();
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    # Gather system information
    my $sysInfo = eval {
        my $facter = iMSCP::ProgramFinder::find( 'facter' ) or die( "Couldn't find facter executable in \$PATH" );
        decode_json( `$facter _2.5.1_ --json os 2> /dev/null` );
    };
    !$@ or die( sprintf( "Couldn't gather system information: %s", $@ ));

    # Reload config in writing mode
    iMSCP::Bootstrapper->getInstance()->loadMainConfig( { nodeferring => 1 } );

    # Fix for the osfamily FACT that is badly detected by FACTER(8) for Devuan
    $sysInfo->{'os'}->{'osfamily'} = 'Debian' if $sysInfo->{'os'}->{'lsb'}->{'distid'} eq 'Devuan';

    $self->{'config'}->{'DISTRO_FAMILY'} = $sysInfo->{'os'}->{'family'};
    debug( sprintf( 'Distribution family set to: %s', $self->{'config'}->{'DISTRO_FAMILY'} ));

    $self->{'config'}->{'DISTRO_ID'} = $sysInfo->{'os'}->{'lsb'}->{'distid'};
    debug( sprintf( 'Distribution ID set to: %s', $self->{'config'}->{'DISTRO_ID'} ));

    $self->{'config'}->{'DISTRO_CODENAME'} = $sysInfo->{'os'}->{'lsb'}->{'distcodename'};
    debug( sprintf( 'Distribution codename set to: %s', $self->{'config'}->{'DISTRO_CODENAME'} ));

    $self->{'config'}->{'DISTRO_RELEASE'} = $sysInfo->{'os'}->{'lsb'}->{'distrelease'};
    debug( sprintf( 'Distribution release set to: %s', $self->{'config'}->{'DISTRO_RELEASE'} ));

    $self->{'config'}->{'SYSTEM_INIT'} = iMSCP::Service->getInstance()->getInitSystem();
    debug( sprintf( 'System init set to: %s', $self->{'config'}->{'SYSTEM_INIT'} ));

    iMSCP::Bootstrapper->getInstance()->loadMainConfig( { config_readonly => 1 } );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _cleanup( )

 Process cleanup tasks

 Return void, die on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    return unless version->parse( $::imscpOldConfig{'PluginApi'} ) < version->parse( '1.6.0' );

    iMSCP::File->new( filename => "$self->{'config'}->{'LOGROTATE_CONF_DIR'}/imscp" )->remove();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
