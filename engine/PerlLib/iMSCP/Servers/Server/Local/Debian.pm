=head1 NAME

 iMSCP::Servers::Server::Local::Debian - i-MSCP (Debian) Local server implementation

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

package iMSCP::Servers::Server::Local::Debian;

use strict;
use warnings;
use autouse 'iMSCP::Debug' => qw/ debug error /;
use Carp qw/ croak /;
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
    my ($self) = @_;

    my $rs = $self->SUPER::install();
    $rs ||= $self->_cleanup();
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ($self) = @_;

    # Gather system information
    my $sysInfo = eval {
        my $facter = iMSCP::ProgramFinder::find( 'facter' ) or croak( 'facter program not found' );
        decode_json( `$facter --json os 2> /dev/null` );
    };
    if ( $@ ) {
        error( sprintf( "Couldn't gather system information: %s", $@ ));
        return 1;
    }

    # Reload config in writing mode
    iMSCP::Bootstrapper->getInstance()->loadMainConfig( { nodeferring => 1 } );

    $main::imscpConfig{'DISTRO_ID'} = $sysInfo->{'os'}->{'lsb'}->{'distid'};
    debug( sprintf( 'Distribution ID set to: %s', $main::imscpConfig{'DISTRO_ID'} ));

    $main::imscpConfig{'DISTRO_CODENAME'} = $sysInfo->{'os'}->{'lsb'}->{'distcodename'};
    debug( sprintf( 'Distribution codename set to: %s', $main::imscpConfig{'DISTRO_CODENAME'} ));

    $main::imscpConfig{'DISTRO_RELEASE'} = $sysInfo->{'os'}->{'lsb'}->{'distrelease'};
    debug( sprintf( 'Distribution release set to: %s', $main::imscpConfig{'DISTRO_RELEASE'} ));

    $main::imscpConfig{'SYSTEM_INIT'} = iMSCP::Service->getInstance()->getInitSystem();
    debug( sprintf( 'System init set to: %s', $main::imscpConfig{'SYSTEM_INIT'} ));

    iMSCP::Bootstrapper->getInstance()->loadMainConfig( { config_readonly => 1 } );
    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    return 0 unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' )
        && -f "$main::imscpConfig{'LOGROTATE_CONF_DIR'}/imscp";

    iMSCP::File->new( filename => "$main::imscpConfig{'LOGROTATE_CONF_DIR'}/imscp" )->delFile();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
