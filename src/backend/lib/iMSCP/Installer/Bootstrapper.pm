=head1 NAME

 iMSCP::Installer::Bootstrapper - i-MSCP installer bootstrapper

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

# Developer note: Only Perl builtin and modules which are available in Perl
# base installation must be used in that script.

package iMSCP::Installer::Bootstrapper;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Cwd '$CWD';
use iMSCP::Dialog;
use iMSCP::Execute 'executeNoWait';
use iMSCP::Getopt;
use iMSCP::Stepper;
use parent 'iMSCP::Common::Object';

=head1 DESCRIPTION

 i-MSCP installer bootstrapper

=head1 PUBLIC METHODS

=over 4

=item bootstrap( )

 Bootstrap installer

 Return void, die on failure

=cut

sub bootstrap
{
    my ( $self ) = @_;

    if ( $ENV{'IMSCP_FRESH_INSTALL'} ) {
        # Inhibit options that are not relevant in fresh installation context
        iMSCP::Getopt->noninteractive( FALSE ) unless iMSCP::Getopt->preseed;
        iMSCP::Getopt->reconfigure( 'none', FALSE );
        iMSCP::Getopt->skipComposerUpdate( FALSE );
        iMSCP::Getopt->skipDistPackages( FALSE );
    }

    # Inhibit verbose option unless we are in non-interactive mode
    iMSCP::Getopt->verbose( FALSE ) unless iMSCP::Getopt->noninteractive;

    my $distBootstrapFile = "src/backend/lib/iMSCP/Installer/Bootstrapper/@{ [ $self->_getDistBootstrapFile() ] }";
    -f $distBootstrapFile or die(
        sprintf( "The %s distribution installer bootstrap file is missing. Please contact the i-MSCP Team.", $distBootstrapFile )
    );

    # Execute the distribution installer bootstrap file
    do $distBootstrapFile or die;

    $self->_gatherSystemFacts();
    $self->_checkDistSupport();

    # FIXME Should be done before evaluation of distribution installer
    # bootstrap file to avoid installing package on cancellation
    $self->_showWelcomeMsg();
    $self->_confirmInstallOrReconfigure();

    $self->_buildBackendLibrary();
    exit;
}

=back

=head1 PRIVATE METHODS

=over

=item _getDistBootstrapFile

 Get distribution installer bootstrap file

 Return string Distribution installer bootstrap file, die on failure

=cut

sub _getDistBootstrapFile
{
    my ( undef ) = @_;

    # Basic heuristic which should work in most cases
    return 'debian.pl' if -f '/etc/debian_version' || -f '/etc/devuan_version';
    return 'mageia.pl' if -f '/etc/mageia-release';
    return 'redhat.pl' if -f '/etc/redhat-release';
    return 'opensuse.pl' if -f '/etc/os-release' && `grep -q openSUSE /etc/os-release`;
    return 'archlinux.pl' if -f '/etc/arch-release' || -f '/etc/manjaro-release';
    return 'gentoo.pl' if -f '/etc/gentoo-release';
    die( 'Your distribution is not supported yet. Please contact the i-MSCP team.' );
}

=item _gatherSystemFacts

 Gather system facts
 
 Return void, die on failure

=cut

sub _gatherSystemFacts
{
    my ( $self ) = @_;

    require JSON;
    my $facter = iMSCP::ProgramFinder::find( 'facter' ) or die( "Couldn't find facter executable in \$PATH" );
    $self->{'facts'} = JSON->new( { utf8 => TRUE } )->decode( scalar `$facter _2.5.1_ --json architecture os virtual 2> /dev/null` );
    # Fix for the osfamily FACT that is badly detected by FACTER(8) for Devuan (Linux instead of Debian)
    $self->{'facts'}->{'os'}->{'family'} = 'Debian' if $self->{'facts'}->{'os'}->{'lsb'}->{'distid'} eq 'Devuan';
    $self->{'lsb'} = $self->{'facts'}->{'os'}->{'lsb'} or die( "Couldn't retrieve LSB info..." );
}

=item _checkDistSupport( )

 Check distribution support

 Return void, exit if the distribution isn't supported

=cut

sub _checkDistSupport
{
    my ( $self ) = @_;

    unless ( -f "config/$self->{'lsb'}->{'distid'}/packages/@{ [ lc $self->{'lsb'}->{'distcodename'} ] }.xml" ) {
        my $dialog = ( iMSCP::Dialog->getInstance() );
        local @{ ${ $dialog }->{'_opts'} }{qw/ titleok-button /} = ( 'Unsupported distribution', 'Abort' );
        ${ $dialog }->msgbox( <<"EOF" );
We are sorry but your distribution $self->{'lsb'}->{'distdescription'} isn't supported by this i-MSCP version.
        
If your distribution is already supported in an \\Zbearlier\\ZB release, you can try to copy the package file of the release that is closest to your distribution and try again. For instance:
        
 \\Zb# cp config/$self->{'lsb'}->{'distid'}/packages/<codename>.xml src/$self->{'lsb'}->{'distid'}/packages/$self->{'lsb'}->{'distcodename'}.xml
 # perl imscp-installer -d\\ZB

 where \\Zb<codename>\\ZB must be the codename of the closest supported release.

If that still doesn't work, you'll have to wait for a new i-MSCP version.
EOF
        exit 1;
    }
}

=cut

=item _showWelcomeMsg( )

 Show welcome message

 Return void, exit on ESC

=cut

sub _showWelcomeMsg
{
    return if iMSCP::Getopt->noninteractive || !grep ( $_ eq 'none', @{ iMSCP::Getopt->reconfigure } );

    my $dialog = iMSCP::Dialog->getInstance();
    local @{ $dialog->{'_opts'} }{qw/ title yes-button no-button /} = ( 'Welcome to i-MSCP installer', 'Continue', 'Abort' );

    my $rs = $dialog->boolean( <<"EOF" );
\\Zb\\Z4i-MSCP - internet Multi Server Control Panel
____________________________________________\\Zn

Welcome to the i-MSCP installer.

i-MSCP is an open source software (OSS) easing shared hosting management on Linux servers. It comes with a large choice of modules for various services such as Apache2, ProFTPD, Dovecot, Courier, Bind9..., and can be easily extended through plugins and/or event listeners.

i-MSCP is developed for professional Hosting Service Providers (HSPs), Internet Services Providers (ISPs) and IT professionals.

\\Zb\\Z4License
_______\\Zn

Unless otherwise stated all code is licensed under LGPL 2.1 and has the following copyright:

\\ZbCopyright © 2010-2018, Laurent Declercq (i-MSCP™)
All rights reserved.\\ZB
EOF
    exit if $rs != 0;
}

=item _confirmInstallOrReconfigure( )

 Confirm installation or reconfiguration

 Return void, exit on ESC or Abort

=cut

sub _confirmInstallOrReconfigure
{
    my ( $self ) = @_;

    return if iMSCP::Getopt->noninteractive;

    my ( $dialog, $retval ) = ( iMSCP::Dialog->getInstance(), 0 );
    local @{ $dialog->{'_opts'} }{qw/ yes-button no-button /} = ( 'Continue', 'Abort' );

    if ( grep ( $_ eq 'none', @{ iMSCP::Getopt->reconfigure } ) ) {
        local $dialog->{'_opts'}->{'title'} = 'Installation confirmation';
        $retval = $dialog->boolean( <<"EOF", TRUE );
This program will install or update i-MSCP and all software dependencies on your $self->{'lsb'}->{'distdescription'} system.

If you're updating from an older i-MSCP version, be sure to have read the errata file located at \\Zbhttps://github.com/i-MSCP/imscp/blob/1.5.x/docs/1.5.x_errata.md\\ZB before continue as some manual tasks could be required.

While setup dialog, you can back up to previous dialogs by hitting the escape keystroke or back button. You can also scroll down texts of dialogs by hitting the arrow keystrokes.

\\ZbPlease confirm that you want to continue.\\ZB

EOF
    } else {
        local $dialog->{'_opts'}->{'title'} = 'Installation confirmation';
        $retval = $dialog->boolean( <<"EOF", TRUE );
This program will update and/or reconfigure your i-MSCP installation.

While setup dialog, you can back up to previous dialogs by hitting the escape keystroke or back button. You can also scroll down texts of dialogs by hitting the arrow keystrokes.

\\ZbPlease confirm that you want to continue.\\ZB

EOF
    }

    exit if $retval != 0;
}

=item _buildBackendLibrary( )

 Build backend library

 Return void, die on failure

=cut

sub _buildBackendLibrary
{
    step(
        sub {
            local $CWD = 'src/backend';
            my ( $retval, $stderr );
            $retval = executeNoWait( [ 'make', 'realclean' ], \&_cmdStdoutRoutine, sub { $stderr .= $_[0] } ) if -f 'Makefile';
            $retval ||= executeNoWait( [ 'perl', 'Makefile.PL' ], \&_cmdStdoutRoutine, sub { $stderr .= $_[0] } );
            $retval ||= executeNoWait( [ 'make', $ENV{'IMSCP_DEVELOP'} ? 'DEFINE=-DDEBUG' : () ], \&_cmdStdoutRoutine, sub { $stderr .= $_[0] } );
            $retval == 0 or die( sprintf( "Couldn't build i-MSCP backend library: %s", $stderr || 'Unknown error' ));

        },
        'Building backend library...', 3, 1
    );
}

=item _cmdStdoutRoutine( $output )

 Command STDOUT routine

 Param string $output Command Output

=cut

sub _cmdStdoutRoutine
{
    chomp( my $output = $_[0] );
    iMSCP::Debug::debug( $output, FALSE );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
