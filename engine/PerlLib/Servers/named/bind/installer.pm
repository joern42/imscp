=head1 NAME

 Servers::named::bind::installer - i-MSCP Bind9 Server implementation

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by internet Multi Server Control Panel
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

package Servers::named::bind::installer;

use strict;
use warnings;
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Debug;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList isStringNotInList isValidEmail isValidHostname /;
use iMSCP::Dir;
use iMSCP::EventManager;
use iMSCP::Execute;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Net;
use iMSCP::ProgramFinder;
use iMSCP::Service;
use iMSCP::TemplateParser;
use iMSCP::Umask;
use List::MoreUtils qw/ uniq /;
use Servers::named::bind;
use Socket qw/ :DEFAULT inet_ntop inet_pton getnameinfo /;
use version;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 Installer for the i-MSCP Bind9 Server implementation.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( $eventManager )

 Register setup event listeners

 Param iMSCP::EventManager $eventManager
 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
    my ( $self, $eventManager ) = @_;

    $eventManager->register(
        'beforeSetupDialog',
        sub {
            push @{ $_[0] },
                sub { $self->askForDnsServerType( @_ ) },
                sub { $self->askForDnsIPv6Support( @_ ) },
                sub { $self->askForMasterDnsServer( @_ ) },
                sub { $self->askForMasterDnsServerIpPolicy( @_ ) },
                sub { $self->askForSlaveDnsServers( @_ ) },
                sub { $self->askForLocalDnsResolver( @_ ) };
            0;
        }
    );
}

=item askForDnsServerType( $dialog )

 Ask for the DNS server type to configure

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub askForDnsServerType
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'BIND_TYPE', $self->{'config'}->{'BIND_TYPE'} );
    $self->{'oldBindType'} = $value unless length $self->{'oldBindType'};

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named_type', 'named', 'alternatives', 'all' ] )
        || isStringNotInList( $value, 'master', 'slave' )
    ) {
        my %choices = ( 'master', 'Master DNS server', 'slave', 'Slave DNS server' );
        ( my $rs, $value ) = $dialog->radiolist( <<'EOF', \%choices, ( grep ( $value eq $_, keys %choices ) )[0] || 'master' );

Please select the type of DNS server that you want to configure:
\Z \Zn
EOF
        return $rs unless $rs < 30;
    }

    $self->{'config'}->{'BIND_TYPE'} = $value;
    ::setupSetQuestion( 'BIND_TYPE', $self->{'config'}->{'BIND_TYPE'} );
    0;
}

=item askForDnsIPv6Support( $dialog )

 Ask for DNS IPv6 support

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 20 (SKIP), 30 (BACK), 50 (ESC)

=cut

sub askForDnsIPv6Support
{
    my ( $self, $dialog ) = @_;

    if ( ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'no' ) {
        $self->{'config'}->{'BIND_IPV6'} = 'no';
        ::setupGetQuestion( 'BIND_IPV6', 'no' );
        return 20;
    }

    my $value = ::setupGetQuestion( 'BIND_IPV6', $self->{'config'}->{'BIND_IPV6'} );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named_ipv6', 'named', 'alternatives', 'all' ] )
        || isStringNotInList( $value, 'yes', 'no' )
    ) {
        my $rs = $dialog->yesno( <<'EOF', $value eq 'no', TRUE );

Do you want to enable the IPv6 support for the DNS server?
EOF
        return $rs unless $rs < 30;
        $value = $rs ? 'no' : 'yes';
    }

    $self->{'config'}->{'BIND_IPV6'} = $value;
    ::setupSetQuestion( 'BIND_IPV6', $value );
    0;
}

=item askForMasterDnsServerIpPolicy( $dialog )

 Ask for master DNS server IP addresses policy

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 20 (SKIP), 30 (BACK), 50 (ESC)

=cut

sub askForMasterDnsServerIpPolicy
{
    my ( $self, $dialog ) = @_;

    if ( ::setupGetQuestion( 'BIND_TYPE' ) eq 'slave' ) {
        $self->{'config'}->{'BIND_ENFORCE_ROUTABLE_IPS'} = '';
        return 20;
    }

    my $value = ::setupGetQuestion( 'BIND_ENFORCE_ROUTABLE_IPS', $self->{'config'}->{'BIND_ENFORCE_ROUTABLE_IPS'} );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named_ips_policy', 'named', 'alternatives', 'all' ] )
        || isStringNotInList( $value, 'yes', 'no' )
    ) {
        ( my $rs, $value ) = $dialog->yesno( <<"EOF", $value eq 'no', TRUE );

Do you want enforce routable IP addresses in DNS zone files?

If you say 'yes', the server public IP will be used in place of the client domain IP addresses (A/AAAA records) when those are non-routable.
EOF
        return $rs unless $rs < 30;
        $value = $rs ? 'no' : 'yes';
    }

    $self->{'config'}->{'BIND_ENFORCE_ROUTABLE_IPS'} = $value;
    ::setupSetQuestion( 'BIND_ENFORCE_ROUTABLE_IPS', $value );
    0;
}

=item askForMasterDnsServer( $dialog )

 Ask for master name server IP addresses and names (depending of nameserver type)
 
 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub askForMasterDnsServer
{
    my ( $self, $dialog ) = @_;

    my $type = ::setupGetQuestion( 'BIND_TYPE' );
    my @ips = split /[,; ]+/, ::setupGetQuestion( 'BIND_MASTER_IP_ADDRESSES', $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} );
    my @names = split /[,; ]+/, ::setupGetQuestion( 'BIND_MASTER_NAMES', $self->{'config'}->{'BIND_MASTER_NAMES'} );
    my $email = ::setupGetQuestion( 'BIND_HOSTMASTER_EMAIL', $self->{'config'}->{'BIND_HOSTMASTER_EMAIL'} );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named_master', 'named', 'alternatives', 'all' ] )
        # Not configured yet, badly configured, invalid IP address(s) or invalid name(s)
        || ( $type eq 'master' && (
            !@ips || !@names || !length $email || ( $email ne 'none' && !isValidEmail( $email ) )
            || @ips != @names || ( $ips[0] eq 'none' && $names[0] ne 'none' ) || ( $ips[0] ne 'none' && @names eq 'none' )  
            || ( $ips[0] ne 'none' && !$self->_checkIpAdresses( @ips ) ) || ( $ips[0] ne 'none' && grep ( isValidHostname( $_ ), @names) < @names )
        ) )
        # Not configured yet, badly configured or invalid IP address(es)
        || ( $type eq 'slave' && ( !@ips || @names || $ips[0] eq 'none' || !$self->_checkIpAdresses( @ips ) ) )
    ) {
        my $rs = 0;

        Q1:
        return $rs if $rs == 30 && $type eq 'slave';

        if ( $type eq 'master' ) {
            $rs = $dialog->yesno( <<'EOF', !@ips || $ips[0] eq 'none', TRUE );

Do you want to set the IP addresses and names for the master DNS server?

Historically, the master DNS server was configured on a per zone basis, using the client domain names and associated IP addresses. However, a DNS server \ZbSHOULD\ZB have a correct reverse DNS (PTR record) what is difficult to achieve with the historical behavior as this involve different IP addresses per DNS zone while in a shared hosting environment, IP addresses are often shared.

Furthermore, it is not viable for the administrator to create new DNS glue records each time a new domain is added through the control panel.

That is why the installer now give the possibility to set the IP addresses and names for the master DNS server which will be used in all DNS zone files.

If you say 'no' (default), i-MSCP will stick to historical behavior as explained above.
EOF
            return $rs unless $rs < 30;
        }

        if ( $rs == 0 || $type eq 'slave' ) {
            ( my $msg, @ips ) = ( '', grep ( $_ ne 'none', @ips ) );

            Q2:
            do {
                ( $rs, my $ips ) = $dialog->inputbox( <<"EOF", ::setupGetQuestion( 'BIND_TYPE' ) eq $self->{'oldBindType'} ? "@ips" : '' );
$msg
@{ [ 
    ( $self->{'config'}->{'BIND_IPV6'} eq 'yes'
        ? ( $type eq 'master'
            ? 'Please enter a space separated list of IP addresses for the master DNS server, generally one IPv4 and one IPv6 if you want to enable dual-stack:'
            : 'Please enter a space separated list of IP addresses for the authoritative DNS servers:'
        )
        : ($type eq 'master'
            ? 'Please enter the IP address (IPv4) for the master DNS server:'
            : 'Please enter a space separated list of IP addresses for the authoritative DNS servers (IPv4 only):'
        )
    ) . ( $type eq 'master' ? '' : "\n\nAuthoritative name servers are those listed in the \\Zb'masters'\\ZB statement of the slave zones." )
] }
\\Z \\Zn
EOF
                return $rs if $rs == 50;
                goto Q1 if $rs == 30;

                @ips = uniq( split ' ', $ips );
                $msg = !@ips || !$self->_checkIpAdresses( @ips ) ? <<"EOF" : '';

@{ [ @ips ? '\Z1Invalid IP address found.\Zn' : '\Z1At least one IP address is required\Zn' ] } 
EOF
            } while !@ips || length $msg;

            if ( $type eq 'master' && grep ( $_ ne 'none', @ips ) ) {
                Q3:
                @names = () if $names[0] && $names[0] eq 'none';
                @names = splice @names, 0, @ips if @names > @ips;

                my @dialogs;
                for my $idx ( 0 .. $#ips ) {
                    push @dialogs, sub {
                        do {
                            ( $rs, $names[$idx] ) = $dialog->inputbox(
                                <<"EOF", $names[$idx] || _getReverseDNS( $ips[$idx] ));
$msg
Please enter the DNS server name associated with the $ips[$idx] IP address (leave empty for default):

Default value is the result of a reverse DNS lookup.
\\Z \\Zn
EOF
                            return $rs unless $rs < 30;

                            $msg = !length $names[$idx] || isValidHostname( $names[$idx] ) ? '' : <<'EOF';

\Z1Invalid DNS server name.\Zn
EOF
                        } while !length $names[$idx] || length $msg;
                        0;
                    };
                }

                $rs = $dialog->executeDialogs( \@dialogs );
                goto Q2 if $rs == 30;
                return $rs if $rs == 50;

                $iMSCP::Dialog::InputValidation::lastValidationError = '';

                do {
                    $iMSCP::Dialog::InputValidation::lastValidationError = '' unless length $email;

                    ( $rs, $email ) = $dialog->inputbox( <<"EOF", $email && $email ne 'none' ? $email : "hostmaster\@$names[0]" );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter the email address for the person responsible for the DNS zones (leave emtpy for default):

Default value is generated using DNS server name. 

Enter 'none' if you prefer historical behavior where the email address is generated on a per zone basis, using the client domains such as hostmaster\@domain.tld.

See https://tools.ietf.org/html/rfc2142#section-7 for further details.
\\Z \\Zn
EOF
                    goto Q3 if $rs == 30;
                    return $rs if $rs == 50;
                } while $email ne 'none' && !isValidEmail( $email );
            } elsif ( $type eq 'master' ) {
                @names = ( 'none' );
                $email = 'none';
            } else {
                @names = ();
                $email = '';
            }
        } elsif ( $type eq 'master' ) {
            @ips = @names = ( 'none' );
            $email = 'none';
        } else {
            @names = ();
            $email = '';
        }
    }

    $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} = "@ips";
    $self->{'config'}->{'BIND_MASTER_NAMES'} = "@names";
    $self->{'config'}->{'BIND_HOSTMASTER_EMAIL'} = $email;
    ::setupSetQuestion( 'BIND_MASTER_IP_ADDRESSES', $self->{'config'}->{'BIND_MASTER_IP_ADDRESSES'} );
    ::setupSetQuestion( 'BIND_MASTER_NAMES', $self->{'config'}->{'BIND_MASTER_NAMES'} );
    ::setupSetQuestion( 'BIND_HOSTMASTER_EMAIL', $self->{'config'}->{'BIND_HOSTMASTER_EMAIL'} );
    0;
}

=item askForSlaveDnsServers( $dialog )

 Ask for the slave DNS server IP addresses

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 20 (SKIP), 30 (BACK), 50 (ESC)
 
=cut

sub askForSlaveDnsServers
{
    my ( $self, $dialog ) = @_;

    if ( ::setupGetQuestion( 'BIND_TYPE' ) eq 'slave' ) {
        $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} = '';
        $self->{'config'}->{'BIND_SLAVE_NAMES'} = '';
        return 20;
    }

    my @ips = split /[,; ]+/, ::setupGetQuestion( 'BIND_SLAVE_IP_ADDRESSES', $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} );
    my @names = split /[,; ]+/, ::setupGetQuestion( 'BIND_SLAVE_NAMES', $self->{'config'}->{'BIND_SLAVE_NAMES'} );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named_slave', 'named', 'alternatives', 'all' ] )
        # Not configured yet or badly configured
        || !@ips || !@names || @ips != @names || ( $ips[0] eq 'none' && $names[0] ne 'none' ) || ( $ips[0] ne 'none' && $names[0] eq 'none' )
        # Invalid IP address(es) or invalid name(s)
        || ( $ips[0] ne 'none' && !$self->_checkIpAdresses( @ips ) ) || ( $ips[0] ne 'none' && grep ( isValidHostname( $_ ), @names) < @names )
    ) {
        Q1:
        my $rs = $dialog->yesno( <<'EOF', !@ips || $ips[0] eq 'none', TRUE );

Do you want to configure slave DNS servers?
EOF
        return $rs unless $rs < 30;

        if ( $rs == 0 ) {
            Q2:
            ( my $msg, @ips ) = ( '', grep ( $_ ne 'none', @ips ) );

            do {
                ( $rs, my $ips ) = $dialog->inputbox( <<"EOF", "@ips" );
$msg
Please enter a space separated list of IP addresses for the slave DNS servers@{ [ $self->{'config'}->{'BIND_IPV6'} eq 'yes' ? '' : ' (IPv4 only)' ] }
\\Z \\Zn
EOF
                return $rs if $rs == 50;
                goto Q1 if $rs == 30;

                @ips = uniq( split ' ', $ips );
                $msg = !@ips || !$self->_checkIpAdresses( @ips ) ? <<"EOF" : '';

@{ [ @ips ? '\Z1Invalid IP address found.\Zn' : '\Z1At least one IP address is required\Zn' ] } 
EOF
                return $rs if $rs == 50;
                goto Q2 if $rs == 30;
            } while !@ips || length $msg;

            Q3:
            $rs = $dialog->yesno( <<'EOF', !@ips || $ips[0] eq 'none', TRUE );

Do you want to set the names for the slave DNS servers?

Historically, the slave DNS servers were configured on a per zone basis, using client domain names. However, a DNS server \ZbSHOULD\ZB have a correct reverse DNS (PTR record) what is difficult to achieve with the historical behavior as this involve different IP addresses per DNS zone while in a shared hosting environment, IP addresses are often shared.

Furthermore, it is not viable for the administrator to create new DNS glue records each time a new domain is added through the control panel.

That is why the installer now give the possibility to set the names for the slave DNS servers which will be used in all DNS zone files.

If you say 'no' (default), i-MSCP will stick to historical behavior as explained above.
EOF

            return $rs if $rs == 50;
            goto Q2 if $rs == 30;

            if ( $rs == 0 ) {
                @names = () if $names[0] && $names[0] eq 'none';
                @names = splice @names, 0, @ips if @names > @ips;

                my @dialogs;
                for my $idx ( 0 .. $#ips ) {
                    push @dialogs, sub {
                        do {
                            ( $rs, $names[$idx] ) = $dialog->inputbox( <<"EOF", $names[$idx] || _getReverseDNS( $ips[$idx] ));
$msg
Please enter the DNS server name associated with the $ips[$idx] IP address (leave empty for default):

Default value is the result of a reverse DNS lookup.
\\Z \\Zn
EOF
                            return $rs unless $rs < 30;

                            $msg = !length $names[$idx] || isValidHostname( $names[$idx] ) ? '' : <<'EOF';

\Z1Invalid DNS server name.\Zn
EOF
                        } while !length $names[$idx] || length $msg;
                        0;
                    };
                }

                $rs = $dialog->executeDialogs( \@dialogs );
                return $rs if $rs == 50;
                goto Q3 if $rs == 30;
            } else {
                @names = ( 'none' );
            }
        } else {
            @ips = @names = ( 'none' );
        }
    }

    $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} = "@ips";
    $self->{'config'}->{'BIND_SLAVE_NAMES'} = "@names";
    ::setupSetQuestion( 'BIND_SLAVE_IP_ADDRESSES', $self->{'config'}->{'BIND_SLAVE_IP_ADDRESSES'} );
    ::setupSetQuestion( 'BIND_SLAVE_NAMES', $self->{'config'}->{'BIND_SLAVE_NAMES'} );
    0;
}

=item askForLocalDnsResolver( $dialog )

 Ask for local DNS resolver

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 20 (SKIP), 30 (BACK), 50 (ESC)

=cut

sub askForLocalDnsResolver
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'LOCAL_DNS_RESOLVER', $self->{'config'}->{'LOCAL_DNS_RESOLVER'} );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named_resolver', 'named', 'alternatives', 'all' ] )
        || isStringNotInList( $value, 'yes', 'no' )
    ) {
        ( my $rs, $value ) = $dialog->yesno( <<'EOF', $value ne 'yes', TRUE );

Do you want use the DNS server as local DNS resolver?
EOF
        return $rs unless $rs < 30;
        $value = $rs ? 'no' : 'yes';
    }

    $self->{'config'}->{'LOCAL_DNS_RESOLVER'} = $value;
    ::setupSetQuestion( 'LOCAL_DNS_RESOLVER', $value );
    0;
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ( $self ) = @_;

    for my $conffile ( 'BIND_CONF_DEFAULT_FILE', 'BIND_CONF_FILE', 'BIND_LOCAL_CONF_FILE', 'BIND_OPTIONS_CONF_FILE' ) {
        if ( $self->{'config'}->{$conffile} ne '' ) {
            my $rs = $self->_bkpConfFile( $self->{'config'}->{$conffile} );
            return $rs if $rs;
        }
    }

    my $rs = $self->_makeDirs();
    $rs ||= $self->_buildConf();
    $rs ||= $self->_oldEngineCompatibility();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return Servers::named::bind::installer

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self->{'named'} = Servers::named::bind->getInstance();
    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/bind";
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'wrkDir'} = "$self->{'cfgDir'}/working";
    $self->{'config'} = $self->{'named'}->{'config'};
    $self;
}

=item _bkpConfFile($cfgFile)

 Backup configuration file

 Param string $cfgFile Configuration file path
 Return int 0 on success, other on failure

=cut

sub _bkpConfFile
{
    my ( $self, $cfgFile ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedBkpConfFile', $cfgFile );
    return $rs if $rs;

    if ( -f $cfgFile ) {
        my $file = iMSCP::File->new( filename => $cfgFile );
        my $filename = basename( $cfgFile );
        unless ( -f "$self->{'bkpDir'}/$filename.system" ) {
            $rs = $file->copyFile( "$self->{'bkpDir'}/$filename.system", { preserve => 'no' } );
            return $rs if $rs;
        } else {
            $rs = $file->copyFile( "$self->{'bkpDir'}/$filename." . time, { preserve => 'no' } );
            return $rs if $rs;
        }
    }

    $self->{'eventManager'}->trigger( 'afterNamedBkpConfFile', $cfgFile );
}

=item _makeDirs( )

 Create directories

 Return int 0 on success, other on failure

=cut

sub _makeDirs
{
    my ( $self ) = @_;

    my @directories = (
        [ $self->{'config'}->{'BIND_DB_MASTER_DIR'}, $self->{'config'}->{'BIND_USER'}, $self->{'config'}->{'BIND_GROUP'}, 02750 ],
        [ $self->{'config'}->{'BIND_DB_SLAVE_DIR'}, $self->{'config'}->{'BIND_USER'}, $self->{'config'}->{'BIND_GROUP'}, 02750 ]
    );

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedMakeDirs', \@directories );
    return $rs if $rs;

    for my $directory ( @directories ) {
        iMSCP::Dir->new( dirname => $directory->[0] )->make( {
            user  => $directory->[1],
            group => $directory->[2],
            mode  => $directory->[3]
        } );
    }

    iMSCP::Dir->new( dirname => $self->{'config'}->{'BIND_DB_MASTER_DIR'} )->clear();

    if ( $self->{'config'}->{'BIND_TYPE'} ne 'slave' ) {
        iMSCP::Dir->new( dirname => $self->{'config'}->{'BIND_DB_SLAVE_DIR'} )->clear();
    }

    $self->{'eventManager'}->trigger( 'afterNamedMakeDirs', \@directories );
}

=item _buildConf( )

 Build configuration file

 Return int 0 on success, other on failure

=cut

sub _buildConf
{
    my ( $self ) = @_;

    # default conffile (Debian/Ubuntu specific)
    if ( $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} && -f $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} ) {
        my $tplName = basename( $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} );
        my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'bind', $tplName, \my $tplContent, {} );
        return $rs if $rs;

        unless ( defined $tplContent ) {
            $tplContent = iMSCP::File->new( filename => $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} )->get();
            unless ( defined $tplContent ) {
                error( sprintf( "Couldn't read %s file", $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} ));
                return 1;
            }
        }

        # Enable/disable local DNS resolver
        $tplContent =~ s/RESOLVCONF=(?:no|yes)/RESOLVCONF=$self->{'config'}->{'LOCAL_DNS_RESOLVER'}/i;

        # Fix for #IP-1333
        my $serviceMngr = iMSCP::Service->getInstance();
        if ( $serviceMngr->isSystemd() ) {
            if ( $self->{'config'}->{'LOCAL_DNS_RESOLVER'} eq 'yes' ) {
                $serviceMngr->enable( 'bind9-resolvconf' );
            } else {
                $serviceMngr->stop( 'bind9-resolvconf' );
                $serviceMngr->disable( 'bind9-resolvconf' );
            }
        }

        # Enable/disable IPV6 support
        if ( $tplContent =~ /OPTIONS="(.*)"/ ) {
            ( my $options = $1 ) =~ s/\s*-[46]\s*//g;
            $options = '-4 ' . $options unless $self->{'config'}->{'BIND_IPV6'} eq 'yes';
            $tplContent =~ s/OPTIONS=".*"/OPTIONS="$options"/;
        }

        $rs = $self->{'eventManager'}->trigger( 'afterNamedBuildConf', \$tplContent, $tplName );
        return $rs if $rs;

        my $file = iMSCP::File->new( filename => "$self->{'wrkDir'}/$tplName" );
        $file->set( $tplContent );

        $rs = $file->save();
        $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $::imscpConfig{'ROOT_GROUP'} );
        $rs ||= $file->mode( 0644 );
        $rs ||= $file->copyFile( $self->{'config'}->{'BIND_CONF_DEFAULT_FILE'} );
        return $rs if $rs;
    }

    # option conffile
    if ( $self->{'config'}->{'BIND_OPTIONS_CONF_FILE'} ) {
        my $tplName = basename( $self->{'config'}->{'BIND_OPTIONS_CONF_FILE'} );
        my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'bind', $tplName, \my $tplContent, {} );
        return $rs if $rs;

        unless ( defined $tplContent ) {
            $tplContent = iMSCP::File->new( filename => "$self->{'cfgDir'}/$tplName" )->get();
            unless ( defined $tplContent ) {
                error( sprintf( "Couldn't read %s file", "$self->{'cfgDir'}/$tplName" ));
                return 1;
            }
        }

        if ( $self->{'config'}->{'BIND_IPV6'} eq 'no' ) {
            $tplContent =~ s/listen-on-v6\s+\{\s+any;\s+\};/listen-on-v6 { none; };/;
        }

        my $namedVersion = $self->_getVersion();
        unless ( defined $namedVersion ) {
            error( "Couldn't retrieve named (Bind9) version" );
            return 1;
        }

        if ( version->parse( $namedVersion ) >= version->parse( '9.9.3' ) ) {
            $tplContent =~ s%//\s+(check-spf\s+ignore;)%$1%;
        }

        $rs = $self->{'eventManager'}->trigger( 'afterNamedBuildConf', \$tplContent, $tplName );
        return $rs if $rs;

        my $file = iMSCP::File->new( filename => "$self->{'wrkDir'}/$tplName" );
        $file->set( $tplContent );

        local $UMASK = 027;

        $rs = $file->save();
        $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'BIND_GROUP'} );
        $rs ||= $file->mode( 0640 );
        $rs ||= $file->copyFile( $self->{'config'}->{'BIND_OPTIONS_CONF_FILE'} );
        return $rs if $rs;
    }

    # master conffile
    if ( $self->{'config'}->{'BIND_CONF_FILE'} ) {
        my $tplName = basename( $self->{'config'}->{'BIND_CONF_FILE'} );
        my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'bind', $tplName, \my $tplContent, {} );
        return $rs if $rs;

        unless ( defined $tplContent ) {
            $tplContent = iMSCP::File->new( filename => "$self->{'cfgDir'}/$tplName" )->get();
            unless ( defined $tplContent ) {
                error( sprintf( "Couldn't read %s file", "$self->{'cfgDir'}/$tplName" ));
                return 1;
            }
        }

        unless ( -f "$self->{'config'}->{'BIND_CONF_DIR'}/bind.keys" ) {
            $tplContent =~ s%include\s+\Q"$self->{'config'}->{'BIND_CONF_DIR'}\E/bind.keys";\n%%;
        }

        $rs = $self->{'eventManager'}->trigger( 'afterNamedBuildConf', \$tplContent, $tplName );
        return $rs if $rs;

        my $file = iMSCP::File->new( filename => "$self->{'wrkDir'}/$tplName" );
        $file->set( $tplContent );

        local $UMASK = 027;

        $rs = $file->save();
        $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'BIND_GROUP'} );
        $rs ||= $file->mode( 0640 );
        $rs ||= $file->copyFile( $self->{'config'}->{'BIND_CONF_FILE'} );
        return $rs if $rs;
    }

    # local conffile
    if ( $self->{'config'}->{'BIND_LOCAL_CONF_FILE'} ) {
        my $tplName = basename( $self->{'config'}->{'BIND_LOCAL_CONF_FILE'} );
        my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'bind', $tplName, \my $tplContent, {} );
        return $rs if $rs;

        unless ( defined $tplContent ) {
            $tplContent = iMSCP::File->new( filename => "$self->{'cfgDir'}/$tplName" )->get();
            unless ( defined $tplContent ) {
                error( sprintf( "Couldn't read %s file", "$self->{'cfgDir'}/$tplName" ));
                return 1;
            }
        }

        $rs = $self->{'eventManager'}->trigger( 'afterNamedBuildConf', \$tplContent, $tplName );
        return $rs if $rs;

        my $file = iMSCP::File->new( filename => "$self->{'wrkDir'}/$tplName" );
        $file->set( $tplContent );

        local $UMASK = 027;

        $rs = $file->save();
        $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'BIND_GROUP'} );
        $rs ||= $file->mode( 0640 );
        $rs ||= $file->copyFile( $self->{'config'}->{'BIND_LOCAL_CONF_FILE'} );
        return $rs if $rs;
    }

    0;
}

=item _checkIpAdresses( @ips)

 Check IP addresses

 Param list @ips List of IP addresses to check
 Return bool TRUE if all IPs are valid, FALSE otherwise

=cut

sub _checkIpAdresses
{
    my ( $self, @ips ) = @_;

    my $reg = $self->{'config'}->{'BIND_IPV6'} eq 'yes' ? qr/^(?:PRIVATE|UNIQUE-LOCAL-UNICAST|PUBLIC|GLOBAL-UNICAST)$/ : qr/^(?:PRIVATE|PUBLIC)$/;
    my $net = iMSCP::Net->getInstance();

    for my $ip ( @ips ) {
        return FALSE unless $net->isValidAddr( $ip ) && $net->getAddrType( $ip ) =~ /$reg/;
    }

    TRUE;
}

=item _getReverseDNS( $ipAddress )

 Get reverse DNS

 Param string $ipAddress
 Return string Reverse DNS or empty string on failure

=cut

sub _getReverseDNS
{
    my ( $ipAddress ) = @_;

    my $sockAddr = iMSCP::Net->getInstance()->getAddrVersion( $ipAddress ) eq 'ipv4'
        ? sockaddr_in( 0, inet_pton( AF_INET, $ipAddress ))
        : sockaddr_in6( 0, inet_pton( AF_INET6, $ipAddress ));
    ( getnameinfo( $sockAddr ) )[1] || '';
}

=item _getVersion( )

 Get named version

 Return string on success, undef on failure

=cut

sub _getVersion
{
    my ( $self ) = @_;

    my $rs = execute( "$self->{'config'}->{'NAMED_BNAME'} -v", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;

    unless ( $rs ) {
        return $1 if $stdout =~ /^BIND\s+([0-9.]+)/;
    }

    undef;
}

=item _oldEngineCompatibility( )

 Remove old files

 Return int 0 on success, other on failure

=cut

sub _oldEngineCompatibility
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNamedOldEngineCompatibility' );
    return $rs if $rs;

    if ( -f "$self->{'cfgDir'}/bind.old.data" ) {
        $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/bind.old.data" )->delFile();
        return $rs if $rs;
    }

    if ( iMSCP::ProgramFinder::find( 'resolvconf' ) ) {
        $rs = execute( "resolvconf -d lo.imscp", \my $stdout, \my $stderr );
        debug( $stdout ) if $stdout;
        error( $stderr || 'Unknown error' ) if $rs;
        return $rs if $rs;
    }

    iMSCP::Dir->new( dirname => $self->{'config'}->{'BIND_DB_ROOT_DIR'} )->clear( undef, qr/\.db$/ );

    $self->{'eventManager'}->trigger( 'afterNameddOldEngineCompatibility' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
