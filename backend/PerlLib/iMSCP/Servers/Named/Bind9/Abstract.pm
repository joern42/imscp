=head1 NAME

 iMSCP::Servers::Named::Bind9::Abstract - i-MSCP Bind9 Server abstract implementation

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

package iMSCP::Servers::Named::Bind9::Abstract;

use strict;
use warnings;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isOneOfStringsInList isStringInList /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Getopt /;
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Net;
use iMSCP::TemplateParser qw/ getBlocByRef process processByRef replaceBlocByRef /;
use iMSCP::Umask;
use version;
use parent 'iMSCP::Servers::Named';

=head1 DESCRIPTION

 i-MSCP Bind9 Server abstract implementation.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 See iMSCP::Servers::Abstract::RegisterSetupListeners()

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeSetupDialog',
        sub { push @{ $_[0] }, sub { $self->askDnsServerMode( @_ ) }, sub { $self->askIPv6Support( @_ ) }, sub { $self->askLocalDnsResolver( @_ ) }; },
        $self->getPriority()
    );
}

=item askDnsServerMode( \%dialog )

 Ask user for DNS server type to configure

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub askDnsServerMode
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'NAMED_MODE', $self->{'config'}->{'NAMED_MODE'} || ( iMSCP::Getopt->preseed ? 'master' : '' ));
    my %choices = ( 'master', 'Master DNS server', 'slave', 'Slave DNS server' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named', 'servers', 'all', 'forced' ] ) || !isStringInList( $value, keys %choices ) ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep ( $value eq $_, keys %choices ) )[0] || 'master' );

Please choose the type of DNS server to configure:
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'NAMED_MODE', $value );
    $self->{'config'}->{'NAMED_MODE'} = $value;
    $self->askDnsServerIps( $dialog );
}

=item askDnsServerIps( \%dialog )

 Ask user for DNS server adresses IP

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub askDnsServerIps
{
    my ( $self, $dialog ) = @_;

    my $dnsServerMode = $self->{'config'}->{'NAMED_MODE'};
    my @masterDnsIps = split /[; \t]+/, ::setupGetQuestion(
        'NAMED_PRIMARY_DNS', $self->{'config'}->{'NAMED_PRIMARY_DNS'} || ( iMSCP::Getopt->preseed ? 'no' : '' )
    );
    my @slaveDnsIps = split /[; \t]+/, ::setupGetQuestion(
        'NAMED_SECONDARY_DNS', $self->{'config'}->{'NAMED_SECONDARY_DNS'} || ( iMSCP::Getopt->preseed ? 'no' : '' )
    );
    my ( $rs, $answer, $msg ) = ( 0, '', '' );

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
        $self->{'config'}->{'NAMED_PRIMARY_DNS'} = 'no';
        $self->{'config'}->{'NAMED_SECONDARY_DNS'} = join ';', @slaveDnsIps;
        return $rs;
    }

    $self->{'config'}->{'NAMED_PRIMARY_DNS'} = join ';', @masterDnsIps;
    ::setupSetQuestion( 'NAMED_PRIMARY_DNS', $self->{'config'}->{'NAMED_PRIMARY_DNS'} );

    ::setupSetQuestion( 'NAMED_SECONDARY_DNS', 'no' );
    $self->{'config'}->{'NAMED_SECONDARY_DNS'} = 'no';
    $rs;
}

=item askIPv6Support( \%dialog )

 Ask user for DNS server IPv6 support

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub askIPv6Support
{
    my ( $self, $dialog ) = @_;

    unless ( ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ) {
        ::setupSetQuestion( 'NAMED_IPV6_SUPPORT', 'no' );
        $self->{'config'}->{'NAMED_IPV6_SUPPORT'} = 'no';
        return 0;
    }

    my $value = ::setupGetQuestion( 'NAMED_IPV6_SUPPORT', $self->{'config'}->{'NAMED_IPV6_SUPPORT'} || ( iMSCP::Getopt->preseed ? 'no' : '' ));
    my %choices = ( 'yes', 'Yes', 'no', 'No' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'named', 'servers', 'all', 'forced' ] ) || !isStringInList( $value, keys %choices ) ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep ( $value eq $_, keys %choices ) )[0] || 'no' );

Do you want to enable IPv6 support for the DNS server?
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'NAMED_IPV6_SUPPORT', $value );
    $self->{'config'}->{'NAMED_IPV6_SUPPORT'} = $value;
    0;
}

=item askLocalDnsResolver( \%dialog )

 Ask user for local DNS resolver

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)

=cut

sub askLocalDnsResolver
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion(
        'NAMED_LOCAL_DNS_RESOLVER', $self->{'config'}->{'NAMED_LOCAL_DNS_RESOLVER'} || ( iMSCP::Getopt->preseed ? 'yes' : '' )
    );
    my %choices = ( 'yes', 'Yes', 'no', 'No' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'resolver', 'named', 'servers', 'all', 'forced' ] )
        || !isStringInList( $value, keys %choices )
    ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep ( $value eq $_, keys %choices ) )[0] || 'yes' );

Do you want to use Bind9 as local DNS resolver?
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    $self->{'config'}->{'NAMED_LOCAL_DNS_RESOLVER'} = $value;
    0;
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    for my $conffile ( 'NAMED_CONF_FILE', 'NAMED_LOCAL_CONF_FILE', 'NAMED_OPTIONS_CONF_FILE' ) {
        next unless length $self->{'config'}->{$conffile};
        $self->_bkpConfFile( $self->{'config'}->{$conffile} );
    }

    $self->_setVersion();
    $self->_makeDirs();
    $self->_configure();
}

=item setBackendPermissions( )

 See iMSCP::Servers::Abstract::setBackendPermissions()

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;

    setRights( $self->{'config'}->{'NAMED_CONF_DIR'}, {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $self->{'config'}->{'NAMED_GROUP'},
        dirmode   => '2750',
        filemode  => '0640',
        recursive => TRUE
    } );
    setRights( $self->{'config'}->{'NAMED_DB_ROOT_DIR'}, {
        user      => $self->{'config'}->{'NAMED_USER'},
        group     => $self->{'config'}->{'NAMED_GROUP'},
        dirmode   => '2750',
        filemode  => '0640',
        recursive => TRUE
    } );
}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ( $self ) = @_;

    'Bind';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ( $self ) = @_;

    sprintf( 'Bind %s', $self->getVersion());
}

=item getVersion( )

 See iMSCP::Servers::Abstract::getVersion()

=cut

sub getVersion
{
    my ( $self ) = @_;

    $self->{'config'}->{'NAMED_VERSION'};
}

=item addDomain( \%moduleData )

 See iMSCP::Servers::Named::addDomain()

=cut

sub addDomain
{
    my ( $self, $moduleData ) = @_;

    # Never process the same zone twice
    # Occurs only in few contexts (eg. when using BASE_SERVER_VHOST as customer domain)
    return if $self->{'seen_zones'}->{$moduleData->{'DOMAIN_NAME'}};

    $self->{'eventManager'}->trigger( 'beforeBindAddDomain', $moduleData );
    $self->_addDmnConfig( $moduleData );
    $self->_addDmnDb( $moduleData ) if $self->{'config'}->{'NAMED_MODE'} eq 'master';
    $self->{'seen_zones'}->{$moduleData->{'DOMAIN_NAME'}} ||= TRUE;
    $self->{'eventManager'}->trigger( 'afterBindAddDomain', $moduleData );
}

=item postaddDomain( \%moduleData )

 See iMSCP::Servers::Named::postaddDomain()

=cut

sub postaddDomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeBindPostAddDomain', $moduleData );

    if ( $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'NAMED_MODE'} eq 'master' && defined $moduleData->{'ALIAS'} ) {
        $self->addSubdomain( {
            REAL_PARENT_DOMAIN_NAME => $moduleData->{'PARENT_DOMAIN_NAME'},
            PARENT_DOMAIN_NAME      => $::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME             => $moduleData->{'ALIAS'} . '.' . $::imscpConfig{'BASE_SERVER_VHOST'},
            EXTERNAL_MAIL           => FALSE,
            DOMAIN_IP               => $moduleData->{'BASE_SERVER_PUBLIC_IP'},
            DOMAIN_TYPE             => 'sub',
            BASE_SERVER_PUBLIC_IP   => $moduleData->{'BASE_SERVER_PUBLIC_IP'},
            OPTIONAL_ENTRIES        => 0,
            STATUS                  => $moduleData->{'STATUS'},
            IS_ALT_URL_RECORD       => TRUE
        } );
    }

    $self->{'reload'} ||= TRUE;
    $self->{'eventManager'}->trigger( 'afterBindPostAddDomain', $moduleData );
}

=item disableDomain( \%moduleData )

 See iMSCP::Servers::Named::disableDomain()

 When a domain is being disabled, we must ensure that the DNS data are still
 present for it (eg: when doing a full upgrade or reconfiguration). This
 explain here why we are executing the addDomain() method.

=cut

sub disableDomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeBindDisableDomain', $moduleData );
    $self->addDomain( $moduleData );
    $self->{'eventManager'}->trigger( 'afterBindDisableDomain', $moduleData );
}

=item postdisableDomain( \%moduleData )

 See iMSCP::Servers::Named::postdisableDomain()

 See the ::disableDomain() method for explaination.

=cut

sub postdisableDomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeBindPostDisableDomain', $moduleData );
    $self->postaddDomain( $moduleData );
    $self->{'eventManager'}->trigger( 'afterBindPostDisableDomain', $moduleData );
}

=item deleteDomain( \%moduleData )

 See iMSCP::Servers::Named::deleteDomain()

=cut

sub deleteDomain
{
    my ( $self, $moduleData ) = @_;

    return if $moduleData->{'PARENT_DOMAIN_NAME'} eq $::imscpConfig{'BASE_SERVER_VHOST'} && !$moduleData->{'FORCE_DELETION'};

    $self->{'eventManager'}->trigger( 'beforeBindDeleteDomain', $moduleData );
    $self->_deleteDmnConfig( $moduleData );

    if ( $self->{'config'}->{'NAMED_MODE'} eq 'master' ) {
        for my $file ( "$self->{'wrkDir'}/$moduleData->{'DOMAIN_NAME'}.db",
            "$self->{'config'}->{'NAMED_DB_MASTER_DIR'}/$moduleData->{'DOMAIN_NAME'}.db"
        ) {
            iMSCP::File->new( filename => $file )->remove();
        }
    }

    $self->{'eventManager'}->trigger( 'afterBindDeleteDomain', $moduleData );
}

=item postdeleteDomain( \%moduleData )

 See iMSCP::Servers::Named::postdeleteDomain()

=cut

sub postdeleteDomain
{
    my ( $self, $moduleData ) = @_;

    return if $moduleData->{'PARENT_DOMAIN_NAME'} eq $::imscpConfig{'BASE_SERVER_VHOST'} && !$moduleData->{'FORCE_DELETION'};

    $self->{'eventManager'}->trigger( 'beforeBindPostDeleteDomain', $moduleData );

    if ( $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'NAMED_MODE'} eq 'master' && defined $moduleData->{'ALIAS'} ) {
        $self->deleteSubdomain( {
            PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME        => $moduleData->{'ALIAS'} . '.' . $::imscpConfig{'BASE_SERVER_VHOST'}
        } );
    }

    $self->{'reload'} ||= TRUE;
    $self->{'eventManager'}->trigger( 'afterBindPostDeleteDomain', $moduleData );
}

=item addSubdomain( \%moduleData )

 See iMSCP::Servers::Named::addSubdomain()

=cut

sub addSubdomain
{
    my ( $self, $moduleData ) = @_;

    return unless $self->{'config'}->{'NAMED_MODE'} eq 'master';

    my $wrkDbFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$moduleData->{'PARENT_DOMAIN_NAME'}.db" );
    my $wrkDbFileContentRef = $wrkDbFile->getAsRef();

    $self->{'eventManager'}->trigger( 'onLoadTemplate', lc $self->getServerName(), 'db_sub.tpl', \my $subEntry, $moduleData );
    $subEntry = iMSCP::File->new( filename => "$self->{'tplDir'}/db_sub.tpl" )->get() unless defined $subEntry;

    unless ( $self->{'serials'}->{$moduleData->{'PARENT_DOMAIN_NAME'}} ) {
        $self->_updateSOAserialNumber( $moduleData->{'PARENT_DOMAIN_NAME'}, $wrkDbFileContentRef, $wrkDbFileContentRef );
    }

    $self->{'eventManager'}->trigger( 'beforeBindAddSubdomain', $wrkDbFileContentRef, \$subEntry, $moduleData );
    my $net = iMSCP::Net->getInstance();

    replaceBlocByRef(
        "; sub MAIL entry BEGIN\n",
        "; sub MAIL entry ENDING\n",
        $moduleData->{'IS_ALT_URL_RECORD'} || $moduleData->{'EXTERNAL_MAIL'} ? '' : process(
            {
                BASE_SERVER_IP_TYPE => ( $net->getAddrVersion( $moduleData->{'BASE_SERVER_PUBLIC_IP'} ) eq 'ipv4' ) ? 'A' : 'AAAA',
                BASE_SERVER_IP      => $moduleData->{'BASE_SERVER_PUBLIC_IP'},
                DOMAIN_NAME         => $moduleData->{'PARENT_DOMAIN_NAME'}
            },
            getBlocByRef( "; sub MAIL entry BEGIN\n", "; sub MAIL entry ENDING\n", \$subEntry )
        ),
        \$subEntry
    );

    if ( defined $moduleData->{'OPTIONAL_ENTRIES'} && !$moduleData->{'OPTIONAL_ENTRIES'} ) {
        replaceBlocByRef( "; sub OPTIONAL entries BEGIN\n", "; sub OPTIONAL entries ENDING\n", '', \$subEntry );
    }

    my $domainIP = $net->isRoutableAddr( $moduleData->{'DOMAIN_IP'} ) ? $moduleData->{'DOMAIN_IP'} : $moduleData->{'BASE_SERVER_PUBLIC_IP'};

    processByRef(
        {
            SUBDOMAIN_NAME => $moduleData->{'DOMAIN_NAME'},
            IP_TYPE        => $net->getAddrVersion( $domainIP ) eq 'ipv4' ? 'A' : 'AAAA',
            DOMAIN_IP      => $domainIP
        },
        \$subEntry
    );
    replaceBlocByRef(
        "; sub [$moduleData->{'DOMAIN_NAME'}] entry BEGIN\n", "; sub [$moduleData->{'DOMAIN_NAME'}] entry ENDING\n", '', $wrkDbFileContentRef
    );
    replaceBlocByRef(
        "; sub [{SUBDOMAIN_NAME}] entry BEGIN\n", "; sub [{SUBDOMAIN_NAME}] entry ENDING\n", $subEntry, $wrkDbFileContentRef, 'preserve'
    );

    $self->{'eventManager'}->trigger( 'afterBindAddSubdomain', $wrkDbFileContentRef, $moduleData );
    $wrkDbFile->save();
    $self->_compileZone( $moduleData->{'PARENT_DOMAIN_NAME'}, $wrkDbFile->{'filename'} );
}

=item postaddSubdomain( \%moduleData )

 See iMSCP::Servers::Named::postaddSubdomain()

=cut

sub postaddSubdomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeBindPostAddSubdomain', $moduleData );

    if ( $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'NAMED_MODE'} eq 'master' && defined $moduleData->{'ALIAS'} ) {
        $self->addSubdomain( {
            REAL_PARENT_DOMAIN_NAME => $moduleData->{'PARENT_DOMAIN_NAME'},
            PARENT_DOMAIN_NAME      => $::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME             => $moduleData->{'ALIAS'} . '.' . $::imscpConfig{'BASE_SERVER_VHOST'},
            EXTERNAL_MAIL           => FALSE,
            DOMAIN_IP               => $moduleData->{'BASE_SERVER_PUBLIC_IP'},
            DOMAIN_TYPE             => 'sub',
            BASE_SERVER_PUBLIC_IP   => $moduleData->{'BASE_SERVER_PUBLIC_IP'},
            OPTIONAL_ENTRIES        => 0,
            STATUS                  => $moduleData->{'STATUS'},
            IS_ALT_URL_RECORD       => TRUE
        } );
    }

    $self->{'reload'} ||= TRUE;
    $self->{'eventManager'}->trigger( 'afterBindPostAddSubdomain', $moduleData );
}

=item disableSubdomain( \%moduleData )

 See iMSCP::Servers::Named::disableSubdomain()

 When a subdomain is being disabled, we must ensure that the DNS data are still present for it (eg: when doing a full
 upgrade or reconfiguration). This explain here why we are executing the addSubdomain() action.

=cut

sub disableSubdomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeBindDisableSubdomain', $moduleData );
    $self->addSubdomain( $moduleData );
    $self->{'eventManager'}->trigger( 'afterBindDisableSubdomain', $moduleData );
}

=item postdisableSubdomain( \%moduleData )

 See iMSCP::Servers::Named::postdisableSubdomain()

 See the ::disableSubdomain( ) method for explaination.

=cut

sub postdisableSubdomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeBindPostDisableSubdomain', $moduleData );
    $self->postaddSubdomain( $moduleData );
    $self->{'eventManager'}->trigger( 'afterBindPostDisableSubdomain', $moduleData );
}

=item deleteSubdomain( \%moduleData )

 See iMSCP::Servers::Named::deleteSubdomain()

=cut

sub deleteSubdomain
{
    my ( $self, $moduleData ) = @_;

    return unless $self->{'config'}->{'NAMED_MODE'} eq 'master';

    my $wrkDbFile = "$self->{'wrkDir'}/$moduleData->{'PARENT_DOMAIN_NAME'}.db";
    -f $wrkDbFile or die( sprintf( 'File %s not found. Run imscp-reconfigure script.', $wrkDbFile ));

    $wrkDbFile = iMSCP::File->new( filename => $wrkDbFile );
    my $wrkDbFileContentRef = $wrkDbFile->getAsRef();

    unless ( $self->{'serials'}->{$moduleData->{'PARENT_DOMAIN_NAME'}} ) {
        $self->_updateSOAserialNumber( $moduleData->{'PARENT_DOMAIN_NAME'}, $wrkDbFileContentRef, $wrkDbFileContentRef );
    }

    $self->{'eventManager'}->trigger( 'beforeBindDeleteSubdomain', $wrkDbFileContentRef, $moduleData );
    replaceBlocByRef(
        "; sub [$moduleData->{'DOMAIN_NAME'}] entry BEGIN\n", "; sub [$moduleData->{'DOMAIN_NAME'}] entry ENDING\n", '', $wrkDbFileContentRef
    );
    $self->{'eventManager'}->trigger( 'afterBindDeleteSubdomain', $wrkDbFileContentRef, $moduleData );
    $wrkDbFile->save();
    $self->_compileZone( $moduleData->{'PARENT_DOMAIN_NAME'}, $wrkDbFile->{'filename'} );
}

=item postdeleteSubdomain( \%moduleData )

 See iMSCP::Servers::Named::postdeleteSubdomain()

=cut

sub postdeleteSubdomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforeBindPostDeleteSubdomain', $moduleData );

    if ( $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes' && $self->{'config'}->{'NAMED_MODE'} eq 'master' && defined $moduleData->{'ALIAS'} ) {
        $self->deleteSubdomain( {
            PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
            DOMAIN_NAME        => $moduleData->{'ALIAS'} . '.' . $::imscpConfig{'BASE_SERVER_VHOST'}
        } );
    }

    $self->{'reload'} ||= TRUE;
    $self->{'eventManager'}->trigger( 'afterBindPostDeleteSubdomain', $moduleData );
}

=item addCustomDNS( \%moduleData )

 See iMSCP::Servers::Named::addCustomDNS()

=cut

sub addCustomDNS
{
    my ( $self, $moduleData ) = @_;

    return unless $self->{'config'}->{'NAMED_MODE'} eq 'master';

    my $wrkDbFile = "$self->{'wrkDir'}/$moduleData->{'DOMAIN_NAME'}.db";
    -f $wrkDbFile or die( sprintf( 'File %s not found. Run imscp-reconfigure script.', $wrkDbFile ));

    $wrkDbFile = iMSCP::File->new( filename => $wrkDbFile );
    my $wrkDbFileContentRef = $wrkDbFile->getAsRef();

    unless ( $self->{'serials'}->{$moduleData->{'DOMAIN_NAME'}} ) {
        $self->_updateSOAserialNumber( $moduleData->{'DOMAIN_NAME'}, $wrkDbFileContentRef, $wrkDbFileContentRef );
    }

    $self->{'eventManager'}->trigger( 'beforeBindAddCustomDNS', $wrkDbFileContentRef, $moduleData );

    my @customDNS = ();
    push @customDNS, join "\t", @{ $_ } for @{ $moduleData->{'DNS_RECORDS'} };

    open my $fh, '<', $wrkDbFileContentRef or die( sprintf( "Couldn't open in-memory file handle: %s", $! ));
    my ( $newWrkDbFileContent, $origin ) = ( '', '' );
    while ( my $line = <$fh> ) {
        my $isOrigin = $line =~ /^\$ORIGIN\s+([^\s;]+).*\n$/;
        $origin = $1 if $isOrigin; # Update $ORIGIN if needed

        unless ( $isOrigin || index( $line, '$' ) == 0 || index( $line, ';' ) == 0 ) {
            # Process $ORIGIN substitutions
            $line =~ s/\@/$origin/g;
            $line =~ s/^(\S+?[^\s.])\s+/$1.$origin\t/;
            # Skip default SPF record line if SPF record for the same DNS name exists in @customDNS
            next if $line =~ /^(\S+)\s+.*?\s+"v=\bspf1\b.*?"/ && grep /^\Q$1\E\s+.*?\s+"v=\bspf1\b.*?"/, @customDNS;
        }

        $newWrkDbFileContent .= $line;
    }
    close( $fh );
    undef $wrkDbFileContentRef;

    replaceBlocByRef(
        "; custom DNS entries BEGIN\n",
        "; custom DNS entries ENDING\n",
        "; custom DNS entries BEGIN\n" . ( join "\n", @customDNS, '' ) . "; custom DNS entries ENDING\n",
        \$newWrkDbFileContent
    );
    $self->{'eventManager'}->trigger( 'afterBindAddCustomDNS', \$newWrkDbFileContent, $moduleData );

    $wrkDbFile->set( $newWrkDbFileContent )->save();
    $self->_compileZone( $moduleData->{'DOMAIN_NAME'}, $wrkDbFile->{'filename'} );
    $self->{'reload'} ||= TRUE;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 See iMSCP::Servers::Named::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    @{ $self }{qw/ restart reload serials seen_zones cfgDir /} = ( FALSE, FALSE, {}, {}, "$::imscpConfig{'CONF_DIR'}/bind" );
    @{ $self }{qw/ bkpDir wrkDir tplDir /} = ( "$self->{'cfgDir'}/backup", "$self->{'cfgDir'}/working", "$self->{'cfgDir'}/parts" );
    $self->SUPER::_init();
}

=item _setVersion( )

 Set Bind version

 Return void, die on failure

=cut

sub _setVersion
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the _setVersion() method', ref $self ));
}

=item _addDmnConfig( \%moduleData )

 Add domain DNS configuration

 Param hashref \%moduleData Data as provided by the Domain|SubAlias modules
 Return void, die on failure

=cut

sub _addDmnConfig
{
    my ( $self, $moduleData ) = @_;

    my ( $cfgFileName, $cfgFileDir ) = fileparse( $self->{'config'}->{'NAMED_LOCAL_CONF_FILE'} || $self->{'config'}->{'NAMED_CONF_FILE'} );
    my $cfgFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$cfgFileName" );
    my $cfgWrkFileContentRef = $cfgFile->getAsRef();
    my $tplFileName = "cfg_$self->{'config'}->{'NAMED_MODE'}.tpl";

    $self->{'eventManager'}->trigger( 'onLoadTemplate', lc $self->getServerName(), $tplFileName, \my $tplCfgEntryContent, $moduleData );
    $tplCfgEntryContent = iMSCP::File->new( filename => "$self->{'tplDir'}/$tplFileName" )->get() unless defined $tplCfgEntryContent;
    $self->{'eventManager'}->trigger( 'beforeBindAddDmnConfig', $cfgWrkFileContentRef, \$tplCfgEntryContent, $moduleData );

    my $tags = {
        NAMED_DB_FORMAT => $self->{'config'}->{'NAMED_DB_FORMAT'} =~ s/=\d//r,
        DOMAIN_NAME     => $moduleData->{'DOMAIN_NAME'}
    };

    if ( $self->{'config'}->{'NAMED_MODE'} eq 'master' ) {
        if ( $self->{'config'}->{'NAMED_SECONDARY_DNS'} ne 'no' ) {
            $tags->{'NAMED_SECONDARY_DNS'} = join( '; ', split( ';', $self->{'config'}->{'NAMED_SECONDARY_DNS'} )) . '; localhost;';
        } else {
            $tags->{'NAMED_SECONDARY_DNS'} = 'localhost;';
        }
    } else {
        $tags->{'NAMED_PRIMARY_DNS'} = join( '; ', split( ';', $self->{'config'}->{'NAMED_PRIMARY_DNS'} )) . ';';
    }

    replaceBlocByRef(
        "// imscp [$moduleData->{'DOMAIN_NAME'}] entry BEGIN\n", "// imscp [$moduleData->{'DOMAIN_NAME'}] entry ENDING\n", '', $cfgWrkFileContentRef
    );
    replaceBlocByRef( "// imscp [{ENTRY_ID}] entry BEGIN\n", "// imscp [{ENTRY_ID}] entry ENDING\n", <<"EOF", $cfgWrkFileContentRef, 'preserve' );
// imscp [$moduleData->{'DOMAIN_NAME'}] entry BEGIN
@{ [ process( $tags, $tplCfgEntryContent ) ] }
// imscp [$moduleData->{'DOMAIN_NAME'}] entry ENDING
EOF
    $self->{'eventManager'}->trigger( 'afterBindAddDmnConfig', $cfgWrkFileContentRef, $moduleData );
    $cfgFile->save()->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'NAMED_GROUP'} )->mode( 0640 )->copy(
        "$cfgFileDir$cfgFileName", { preserve => TRUE }
    );
}

=item _deleteDmnConfig( \%moduleData )

 Delete domain DNS configuration

 Param hashref \%moduleData Data as provided by the Domain|SubAlias modules
 Return void, die on failure

=cut

sub _deleteDmnConfig
{
    my ( $self, $moduleData ) = @_;

    my ( $cfgFileName, $cfgFileDir ) = fileparse( $self->{'config'}->{'NAMED_LOCAL_CONF_FILE'} || $self->{'config'}->{'NAMED_CONF_FILE'} );
    my $cfgFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$cfgFileName" );
    my $cfgWrkFileContentRef = $cfgFile->getAsRef();

    $self->{'eventManager'}->trigger( 'beforeBindDeleteDomainConfig', $cfgWrkFileContentRef, $moduleData );
    replaceBlocByRef(
        "// imscp [$moduleData->{'DOMAIN_NAME'}] entry BEGIN\n", "// imscp [$moduleData->{'DOMAIN_NAME'}] entry ENDING\n", '', $cfgWrkFileContentRef
    );
    $self->{'eventManager'}->trigger( 'afterBindDeleteDomainConfig', $cfgWrkFileContentRef, $moduleData );
    $cfgFile->save()->owner( $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'NAMED_GROUP'} )->mode( 0640 )->copy(
        "$cfgFileDir$cfgFileName", { preserve => TRUE }
    );
}

=item _addDmnDb( \%moduleData )

 Add domain DNS zone file

 Param hashref \%moduleData Data as provided by the Domain|SubAlias modules
 Return void, die on failure

=cut

sub _addDmnDb
{
    my ( $self, $moduleData ) = @_;

    my $wrkDbFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$moduleData->{'DOMAIN_NAME'}.db" );
    my $wrkDbFileContent = -f $wrkDbFile ? $wrkDbFile->get() : undef;

    $self->{'eventManager'}->trigger( 'onLoadTemplate', lc $self->getServerName(), 'db.tpl', \my $tplDbFileC, $moduleData );
    $tplDbFileC = iMSCP::File->new( filename => "$self->{'tplDir'}/db.tpl" )->get() unless defined $tplDbFileC;
    $self->_updateSOAserialNumber( $moduleData->{'DOMAIN_NAME'}, \$tplDbFileC, \$wrkDbFileContent );
    $self->{'eventManager'}->trigger( 'beforeBindAddDomainDb', \$tplDbFileC, $moduleData );

    my $nsRecordB = getBlocByRef( "; dmn NS RECORD entry BEGIN\n", "; dmn NS RECORD entry ENDING\n", \$tplDbFileC );
    my $glueRecordB = getBlocByRef( "; dmn NS GLUE RECORD entry BEGIN\n", "; dmn NS GLUE RECORD entry ENDING\n", \$tplDbFileC );

    my $net = iMSCP::Net->getInstance();
    my $domainIP = $net->isRoutableAddr( $moduleData->{'DOMAIN_IP'} ) ? $moduleData->{'DOMAIN_IP'} : $moduleData->{'BASE_SERVER_PUBLIC_IP'};

    if ( length $nsRecordB || length $glueRecordB ) {
        my @nsIPs = ( $domainIP, ( ( $self->{'config'}->{'NAMED_SECONDARY_DNS'} eq 'no' )
            ? () : split ';', $self->{'config'}->{'NAMED_SECONDARY_DNS'} )
        );
        my ( $nsRecords, $glueRecords ) = ( '', '' );

        for my $ipAddrType ( qw/ ipv4 ipv6 / ) {
            my $nsNumber = 1;
            for my $ipAddr ( @nsIPs ) {
                next unless $net->getAddrVersion( $ipAddr ) eq $ipAddrType;
                $nsRecords .= process( { NS_NAME => 'ns' . $nsNumber }, $nsRecordB ) if length $nsRecordB;
                $glueRecords .= process(
                    {
                        NS_NAME    => 'ns' . $nsNumber,
                        NS_IP_TYPE => ( $ipAddrType eq 'ipv4' ) ? 'A' : 'AAAA',
                        NS_IP      => $ipAddr
                    },
                    $glueRecordB
                ) if length $glueRecordB;

                $nsNumber++;
            }
        }

        replaceBlocByRef( "; dmn NS RECORD entry BEGIN\n", "; dmn NS RECORD entry ENDING\n", $nsRecords, \$tplDbFileC ) if length $nsRecordB;

        if ( length $glueRecordB ) {
            replaceBlocByRef( "; dmn NS GLUE RECORD entry BEGIN\n", "; dmn NS GLUE RECORD entry ENDING\n", $glueRecords, \$tplDbFileC );
        }
    }

    replaceBlocByRef(
        "; dmn MAIL entry BEGIN\n",
        "; dmn MAIL entry ENDING\n",
        $moduleData->{'IS_ALT_URL_RECORD'} || $moduleData->{'EXTERNAL_MAIL'} ? '' : process(
            {
                BASE_SERVER_IP_TYPE => $net->getAddrVersion( $moduleData->{'BASE_SERVER_PUBLIC_IP'} ) eq 'ipv4' ? 'A' : 'AAAA',
                BASE_SERVER_IP      => $moduleData->{'BASE_SERVER_PUBLIC_IP'}
            },
            getBlocByRef( "; dmn MAIL entry BEGIN\n", "; dmn MAIL entry ENDING\n", \$tplDbFileC )
        ),
        \$tplDbFileC
    );
    processByRef(
        {
            DOMAIN_NAME => $moduleData->{'DOMAIN_NAME'},
            IP_TYPE     => $net->getAddrVersion( $domainIP ) eq 'ipv4' ? 'A' : 'AAAA',
            DOMAIN_IP   => $domainIP
        },
        \$tplDbFileC
    );

    unless ( !defined $wrkDbFileContent || iMSCP::Getopt->context() eq 'installer' ) {
        # Re-add subdomain entries
        replaceBlocByRef(
            "; sub entries BEGIN\n",
            "; sub entries ENDING\n",
            getBlocByRef( "; sub entries BEGIN\n", "; sub entries ENDING\n", \$wrkDbFileContent, 'with_tags' ),
            \$tplDbFileC
        );
        # Re-add custom DNS entries
        replaceBlocByRef(
            "; custom DNS entries BEGIN\n",
            "; custom DNS entries ENDING\n",
            getBlocByRef( "; custom DNS entries BEGIN\n", "; custom DNS entries ENDING\n", \$wrkDbFileContent, 'with_tags' ),
            \$tplDbFileC
        );
    }

    $self->{'eventManager'}->trigger( 'afterBindAddDomainDb', \$tplDbFileC, $moduleData );
    $wrkDbFile->set( $tplDbFileC )->save();
    $self->_compileZone( $moduleData->{'DOMAIN_NAME'}, $wrkDbFile->{'filename'} );
}

=item _updateSOAserialNumber( $zone, \$zoneFileContent, \$oldZoneFileContent )

 Update SOA serial number for the given zone
 
 Note: Format follows RFC 1912 section 2.2 recommendations.

 Param string zone Zone name
 Param scalarref \$zoneFileContent Reference to zone file content
 Param scalarref \$oldZoneFileContent Reference to old zone file content
 Return void, die on failure

=cut

sub _updateSOAserialNumber
{
    my ( $self, $zone, $zoneFileContent, $oldZoneFileContent ) = @_;

    $oldZoneFileContent = $zoneFileContent unless defined ${ $oldZoneFileContent };
    ${ $oldZoneFileContent } =~ /^\s+(?:(?<date>\d{8})(?<nn>\d{2})|(?<placeholder>\{TIMESTAMP\}))\s*;[^\n]*\n/m or die(
        sprintf( "Couldn't update SOA serial number for the %s DNS zone: Serial data not found", $zone )
    );

    my %rc = %+;
    my ( $d, $m, $y ) = ( gmtime() )[3 .. 5];
    my $nowDate = sprintf( "%d%02d%02d", $y+1900, $m+1, $d );

    if ( exists $+{'placeholder'} ) {
        $self->{'serials'}->{$zone} = $nowDate . '00';
        processByRef( { TIMESTAMP => $self->{'serials'}->{$zone} }, $zoneFileContent );
        return;
    }

    if ( $rc{'date'} >= $nowDate ) {
        $rc{'nn'}++;

        if ( $rc{'nn'} >= 99 ) {
            $rc{'date'}++;
            $rc{'nn'} = '00';
        }
    } else {
        $rc{'date'} = $nowDate;
        $rc{'nn'} = '00';
    }

    $self->{'serials'}->{$zone} = $rc{'date'} . $rc{'nn'};
    ${ $zoneFileContent } =~ s/^(\s+)(?:\d{10}|\{TIMESTAMP\})(\s*;[^\n]*\n)/$1$self->{'serials'}->{$zone}$2/m;
}

=item _compileZone( $zonename, $filename )

 Compiles the given zone
 
 Param string $zonename Zone name
 Param string $filename Path to zone filename (zone in text format)
 Return void, die on failure
 
=cut

sub _compileZone
{
    my ( $self, $zonename, $filename ) = @_;

    # Zone file must not be created world-readable
    local $UMASK = 0027;
    my $rs = execute(
        [
            'named-compilezone', '-i', 'full', '-f', 'text', '-F', $self->{'config'}->{'NAMED_DB_FORMAT'}, '-s', 'relative', '-o',
            "$self->{'config'}->{'NAMED_DB_MASTER_DIR'}/$zonename.db", $zonename, $filename
        ],
        \my $stdout,
        \my $stderr
    );
    debug( $stdout ) if length $stdout;
    !$rs or die( sprintf( "Couldn't compile the %s zone: %s", $zonename, $stderr || 'Unknown error' ));
}

=item _bkpConfFile($cfgFile)

 Backup configuration file

 Param string $cfgFile Configuration file path
 Return void, die on failure

=cut

sub _bkpConfFile
{
    my ( $self, $cfgFile ) = @_;

    return unless -f $cfgFile;

    my $file = iMSCP::File->new( filename => $cfgFile );
    my $filename = basename( $file );

    unless ( -f "$self->{'bkpDir'}/$filename.system" ) {
        $file->copy( "$self->{'bkpDir'}/$filename.system" );
        return;
    }

    $file->copy( "$self->{'bkpDir'}/$filename." . time );
}

=item _makeDirs( )

 Create directories

 Return void, die on failure

=cut

sub _makeDirs
{
    my ( $self ) = @_;

    my @directories = (
        [ $self->{'config'}->{'NAMED_DB_MASTER_DIR'}, $self->{'config'}->{'NAMED_USER'}, $self->{'config'}->{'NAMED_GROUP'}, 02750 ],
        [ $self->{'config'}->{'NAMED_DB_SLAVE_DIR'}, $self->{'config'}->{'NAMED_USER'}, $self->{'config'}->{'NAMED_GROUP'}, 02750 ]
    );

    for my $directory ( @directories ) {
        iMSCP::Dir->new( dirname => $directory->[0] )->make( {
            user  => $directory->[1],
            group => $directory->[2],
            mode  => $directory->[3]
        } );
    }

    iMSCP::Dir->new( dirname => $self->{'config'}->{'NAMED_DB_MASTER_DIR'} )->clear();
    iMSCP::Dir->new( dirname => $self->{'config'}->{'NAMED_DB_SLAVE_DIR'} )->clear() if $self->{'config'}->{'NAMED_MODE'} ne 'slave';
}

=item _configure( )

 Configure Bind

 Return void, die on failure

=cut

sub _configure
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'beforeBindConfigure' );

    # option configuration file
    if ( $self->{'config'}->{'NAMED_OPTIONS_CONF_FILE'} ) {
        $self->{'eventManager'}->registerOne(
            'beforeBindBuildConfFile',
            sub {
                ${ $_[0] } =~ s/listen-on-v6\s+\{\s+any;\s+\};/listen-on-v6 { none; };/ if $_[5]->{'NAMED_IPV6_SUPPORT'} eq 'no';
                ${ $_[0] } =~ s%//\s+(check-spf\s+ignore;)%$1% if version->parse( $self->getVersion()) >= version->parse( '9.9.3' );
            }
        );

        my $tplName = basename( $self->{'config'}->{'NAMED_OPTIONS_CONF_FILE'} );
        $self->buildConfFile( $tplName, "$self->{'wrkDir'}/$tplName", undef, undef,
            {
                umask => 0027,
                mode  => 0640,
                group => $self->{'config'}->{'NAMED_GROUP'}
            }
        );

        iMSCP::File->new( filename => "$self->{'wrkDir'}/$tplName" )->copy( $self->{'config'}->{'NAMED_OPTIONS_CONF_FILE'}, { preserve => TRUE } );
    }

    # master configuration file
    if ( length $self->{'config'}->{'NAMED_CONF_FILE'} ) {
        $self->{'eventManager'}->registerOne(
            'beforeBindBuildConfFile',
            sub {
                return if -f "$_[5]->{'NAMED_CONF_DIR'}/bind.keys";
                ${ $_[0] } =~ s%include\s+\Q"$_[5]->{'NAMED_CONF_DIR'}\E/bind.keys";\n%%;
            }
        );

        my $tplName = basename( $self->{'config'}->{'NAMED_CONF_FILE'} );
        $self->buildConfFile( $tplName, "$self->{'wrkDir'}/$tplName", undef, undef,
            {
                umask => 0027,
                mode  => 0640,
                group => $self->{'config'}->{'NAMED_GROUP'}
            }
        );

        iMSCP::File->new( filename => "$self->{'wrkDir'}/$tplName" )->copy( $self->{'config'}->{'NAMED_CONF_FILE'}, { preserve => TRUE } );
    }

    # local configuration file
    if ( length $self->{'config'}->{'NAMED_LOCAL_CONF_FILE'} ) {
        my $tplName = basename( $self->{'config'}->{'NAMED_LOCAL_CONF_FILE'} );
        $self->buildConfFile( $tplName, "$self->{'wrkDir'}/$tplName", undef, undef, {
            umask => 0027,
            mode  => 0640,
            group => $self->{'config'}->{'NAMED_GROUP'}
        } );

        iMSCP::File->new( filename => "$self->{'wrkDir'}/$tplName" )->copy( $self->{'config'}->{'NAMED_LOCAL_CONF_FILE'}, { preserve => TRUE } );
    }

    $self->{'eventManager'}->trigger( 'afterBindConfigure' );
}

=item _checkIps(@ips)

 Check IP addresses

 Param list @ips List of IP addresses to check
 Return bool TRUE if all IPs are valid, FALSE otherwise

=cut

sub _checkIps
{
    my ( undef, @ips ) = @_;

    my $net = iMSCP::Net->getInstance();
    my $ValidationRegexp = ::setupGetQuestion( $::imscpConfig{'IPV6_SUPPORT'} ) eq 'yes'
        ? qr/^(?:PRIVATE|UNIQUE-LOCAL-UNICAST|PUBLIC|GLOBAL-UNICAST)$/ : qr/^(?:PRIVATE|UNIQUE-LOCAL-UNICAST|PUBLIC|GLOBAL-UNICAST)$/;

    for my $ipAddr ( @ips ) {
        return 0 unless $net->isValidAddr( $ipAddr ) && $net->getAddrType( $ipAddr ) =~ $ValidationRegexp;
    }

    1;
}

=item _removeConfig( )

 Remove configuration

 Return void, die on failure

=cut

sub _removeConfig
{
    my ( $self ) = @_;

    for my $file ( 'NAMED_CONF_FILE', 'NAMED_LOCAL_CONF_FILE', 'NAMED_OPTIONS_CONF_FILE' ) {
        next unless exists $self->{'config'}->{$file};
        my ( $filename, $dirname ) = fileparse( $self->{'config'}->{$file} );
        next unless -d $dirname && -f "$self->{'bkpDir'}/$filename.system";

        iMSCP::File->new( filename => "$self->{'bkpDir'}/$filename.system" )->copy( $self->{'config'}->{$file} );
        iMSCP::File->new( filename => $self->{'config'}->{$file} )->mode( 0640 )->owner(
            $::imscpConfig{'ROOT_USER'}, $self->{'config'}->{'NAMED_GROUP'}
        );
    }

    iMSCP::Dir->new( dirname => $self->{'config'}->{'NAMED_DB_MASTER_DIR'} )->remove();
    iMSCP::Dir->new( dirname => $self->{'config'}->{'NAMED_DB_SLAVE_DIR'} )->remove();
    iMSCP::Dir->new( dirname => $self->{'wrkDir'} )->clear();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
