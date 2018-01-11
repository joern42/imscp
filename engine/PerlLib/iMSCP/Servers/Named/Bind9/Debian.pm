=head1 NAME

 iMSCP::Servers::Named::Bind9::Debian - i-MSCP (Debian) Bind9 server implementation

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

package iMSCP::Servers::Named::Bind9::Debian;

use strict;
use warnings;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isOneOfStringsInList isStringInList /;
use Class::Autouse  qw/ :nostat iMSCP::Getopt /;
use File::Basename;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::ProgramFinder;
use iMSCP::Service;
use version;
use parent 'iMSCP::Servers::Named::Bind9::Abstract';

our $VERSION = '1.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Bind9 server implementation.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 See iMSCP::Servers::Abstract::RegisterSetupListeners()

=cut

sub registerSetupListeners
{
    my ($self) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeSetupDialog',
        sub {
            push @{$_[0]},
                sub { $self->askDnsServerMode( @_ ) },
                sub { $self->askIPv6Support( @_ ) },
                sub { $self->askLocalDnsResolver( @_ ) };
            0;
        },
        $self->getPriority()
    );
}

=item askDnsServerMode( \%dialog )

 Ask user for DNS server type to configure

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub askDnsServerMode
{
    my ($self, $dialog) = @_;

    my $value = main::setupGetQuestion( 'BIND_MODE', $self->{'config'}->{'BIND_MODE'} || ( iMSCP::Getopt->preseed ? 'master' : '' ));
    my %choices = ( 'master', 'Master DNS server', 'slave', 'Slave DNS server' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named', 'servers', 'all', 'forced' ] ) || !isStringInList( $value, keys %choices ) ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep( $value eq $_, keys %choices ) )[0] || 'master' );
Please choose the type of DNS server to configure:
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    $self->{'config'}->{'BIND_MODE'} = $value;
    $self->askDnsServerIps( $dialog );
}

=item askDnsServerIps( \%dialog )

 Ask user for DNS server adresses IP

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub askDnsServerIps
{
    my ($self, $dialog) = @_;

    my $dnsServerMode = $self->{'config'}->{'BIND_MODE'};
    my @masterDnsIps = split /[; \t]+/, main::setupGetQuestion(
            'PRIMARY_DNS', $self->{'config'}->{'PRIMARY_DNS'} || ( iMSCP::Getopt->preseed ? 'no' : '' )
        );
    my @slaveDnsIps = split /[; \t]+/, main::setupGetQuestion(
            'SECONDARY_DNS', $self->{'config'}->{'SECONDARY_DNS'} || ( iMSCP::Getopt->preseed ? 'no' : '' )
        );
    my ($rs, $answer, $msg) = ( 0, '', '' );

    if ( $dnsServerMode eq 'master' ) {
        if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named', 'servers', 'all', 'forced' ] )
            || !@slaveDnsIps
            || ( $slaveDnsIps[0] ne 'no' && !$self->_checkIps( @slaveDnsIps ) )
        ) {
            my %choices = ( 'yes', 'Yes', 'no', 'No' );
            ( $rs, $answer ) = $dialog->radiolist( <<"EOF", \%choices, !@slaveDnsIps || $slaveDnsIps[0] eq 'no' ? 'no' : 'yes' );
Do you want to add slave DNS servers?
\\Z \\Zn
EOF
            if ( $rs < 30 && $answer eq 'yes' ) {
                @slaveDnsIps = () if @slaveDnsIps && $slaveDnsIps[0] eq 'no';

                do {
                    ( $rs, $answer ) = $dialog->inputbox( <<"EOF", join ' ', @slaveDnsIps );
$msg
Please enter the IP addresses for the slave DNS servers, each separated by a space or semicolon:
EOF
                    $msg = '';
                    if ( $rs < 30 ) {
                        @slaveDnsIps = split /[; ]+/, $answer;

                        if ( !@slaveDnsIps ) {
                            $msg = <<"EOF";
\\Z1You must enter at least one IP address.\\Zn
EOF

                        } elsif ( !$self->_checkIps( @slaveDnsIps ) ) {
                            $msg = <<"EOF"
\\Z1Wrong or disallowed IP address found.\\Zn
EOF
                        }
                    }
                } while $rs < 30 && $msg;
            } else {
                @slaveDnsIps = ( 'no' );
            }
        }
    } elsif ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named', 'servers', 'all', 'forced' ] )
        || !@slaveDnsIps
        || $slaveDnsIps[0] eq 'no'
        || !$self->_checkIps( @masterDnsIps )
    ) {
        @masterDnsIps = () if @masterDnsIps && $masterDnsIps[0] eq 'no';

        do {
            ( $rs, $answer ) = $dialog->inputbox( <<"EOF", join ' ', @masterDnsIps );
$msg
Please enter the IP addresses for the master DNS server, each separated by space or semicolon:
EOF
            $msg = '';
            if ( $rs < 30 ) {
                @masterDnsIps = split /[; ]+/, $answer;

                if ( !@masterDnsIps ) {
                    $msg = <<"EOF";
\\Z1You must enter a least one IP address.\\Zn
EOF
                } elsif ( !$self->_checkIps( @masterDnsIps ) ) {
                    $msg = <<"EOF";
\\Z1Wrong or disallowed IP address found.\\Zn
EOF
                }
            }
        } while $rs < 30 && $msg;
    }

    return $rs unless $rs < 30;

    if ( $dnsServerMode eq 'master' ) {
        $self->{'config'}->{'PRIMARY_DNS'} = 'no';
        $self->{'config'}->{'SECONDARY_DNS'} = join ';', @slaveDnsIps;
        return $rs;
    }

    $self->{'config'}->{'PRIMARY_DNS'} = join ';', @masterDnsIps;
    $self->{'config'}->{'SECONDARY_DNS'} = 'no';
    $rs;
}

=item askIPv6Support( \%dialog )

 Ask user for DNS server IPv6 support

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub askIPv6Support
{
    my ($self, $dialog) = @_;

    unless ( main::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ) {
        $self->{'config'}->{'BIND_IPV6'} = 'no';
        return 0;
    }

    my $value = main::setupGetQuestion( 'BIND_IPV6', $self->{'config'}->{'BIND_IPV6'} || ( iMSCP::Getopt->preseed ? 'no' : '' ));
    my %choices = ( 'yes', 'Yes', 'no', 'No' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named', 'servers', 'all', 'forced' ] ) || !isStringInList( $value, keys %choices ) ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep( $value eq $_, keys %choices ) )[0] || 'no' );
Do you want to enable IPv6 support for the DNS server?
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    $self->{'config'}->{'BIND_IPV6'} = $value;
    0;
}

=item askLocalDnsResolver( \%dialog )

 Ask user for local DNS resolver

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub askLocalDnsResolver
{
    my ($self, $dialog) = @_;

    my $value = main::setupGetQuestion(
        'LOCAL_DNS_RESOLVER', $self->{'config'}->{'LOCAL_DNS_RESOLVER'} || ( iMSCP::Getopt->preseed ? 'yes' : '' )
    );
    my %choices = ( 'yes', 'Yes', 'no', 'No' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'resolver', 'named', 'servers', 'all', 'forced' ] )
        || !isStringInList( $value, keys %choices )
    ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep( $value eq $_, keys %choices ) )[0] || 'yes' );
Do you want to use the local DNS resolver?
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    $self->{'config'}->{'LOCAL_DNS_RESOLVER'} = $value;
    0;
}

=item preinstall( )

 See iMSCP::Servers::Abstract::preinstall()

=cut

sub preinstall
{
    my ($self) = @_;

    0; # We do not want stop the service while installation/reconfiguration
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ($self) = @_;

    my $rs = $self->SUPER::install();
    $rs ||= $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->enable( 'bind9' ); };
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

    my $rs = $self->_removeConfig();
    return $rs if $rs;

    eval {
        my $serviceMngr = iMSCP::Service->getInstance();
        $serviceMngr->restart( 'bind9' ) if $serviceMngr->hasService( 'bind9' ) && $serviceMngr->isRunning( 'bind9' );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->start( 'bind9' ); };
    if ( $@ ) {
        error( $@ );
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

    eval { iMSCP::Service->getInstance()->stop( 'bind9' ); };
    if ( $@ ) {
        error( $@ );
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

    eval { iMSCP::Service->getInstance()->restart( 'bind9' ); };
    if ( $@ ) {
        error( $@ );
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

    eval { iMSCP::Service->getInstance()->reload( 'bind9' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVersion()

 See iMSCP::Servers::Named::Bind9::Abstract::_setVersion()

=cut

sub _setVersion
{
    my ($self) = @_;

    my $rs = execute( [ '/usr/bin/bind9-config', '--version' ], \ my $stdout, \ my $stderr );
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    if ( $stdout !~ /version=([\d.]+)/i ) {
        error( "Couldn't guess Bind9 version from the `/usr/bin/bind9-config --version` command output" );
        return 1;
    }

    $self->{'config'}->{'BIND_VERSION'} = $1;
    debug( sprintf( 'Bind9 version set to: %s', $1 ));
    0;
}

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    return 0 unless version->parse( $main::imscpOldConfig{'PluginApi'} ) < version->parse( '1.5.1' );

    if ( -f "$self->{'cfgDir'}/bind.old.data" ) {
        my $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/bind.old.data" )->delFile();
        return $rs if $rs;
    }

    if ( iMSCP::ProgramFinder::find( 'resolvconf' ) ) {
        my $rs = execute( "resolvconf -d lo.imscp", \ my $stdout, \ my $stderr );
        debug( $stdout ) if $stdout;
        error( $stderr || 'Unknown error' ) if $rs;
        return $rs if $rs;
    }

    eval { iMSCP::Dir->new( dirname => $self->{'config'}->{'BIND_DB_ROOT_DIR'} )->clear( undef, qr/\.db$/ ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _shutdown( $priority )

 See iMSCP::Servers::Abstract::_shutdown()

=cut

sub _shutdown
{
    my ($self, $priority) = @_;

    return unless my $action = $self->{'restart'} ? 'restart' : ( $self->{'reload'} ? 'reload' : undef );

    iMSCP::Service->getInstance()->registerDelayedAction( 'bind9', [ $action, sub { $self->$action(); } ], $priority );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
