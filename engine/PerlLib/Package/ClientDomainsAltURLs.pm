=head1 NAME

 Package::ClientDomainsAltURLs - i-MSCP Alternative URLs fo client domains

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

package Package::ClientDomainsAltURLs;

use strict;
use warnings;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isOneOfStringsInList isStringInList /;
use iMSCP::Boolean;
use Scalar::Defer qw/ lazy /;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 Alternative URLs for client domains.
 
 Alternative URLs make the clients able to access their websites through
 control panel subdomains such as dmn1.panel.domain.tld.

 This feature is useful for customers who have not yet updated their DNS so
 that their domain name points to the IP address of the server that has been
 assigned to them.
 
 This feature is only made available when the i-MSCP server act as master DNS
 server through the bind9 server implementation.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( $eventManager )

 Register setup event listeners

 Param iMSCP::EventManager $eventManager
 Return int 0 on success, other on failure

=cut

sub registerSetupListeners
{
    my ( undef, $eventManager ) = @_;

    $eventManager->register( 'beforeSetupDialog', sub {
        push @{ $_[0] }, \&askForClientDomainsAltURLs;
        0;
    } );
}

=item getPriority( )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    0;
}

=item postaddDmn( \%data )

 Add DNS (A/AAAA) record for client domain alternative URL

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub postaddDmn
{
    my ( $self, $data ) = @_;

    return 0 unless $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes';

    $self->{'named'}->addSub( {
        PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
        DOMAIN_NAME        => "$data->{'DOMAIN_TYPE'}$data->{'DOMAIN_ID'}.$::imscpConfig{'BASE_SERVER_VHOST'}",
        MAIL_ENABLED       => FALSE,
        DOMAIN_IP          => $data->{'BASE_SERVER_PUBLIC_IP'}
    } );
}

=item postdeleteDmn( \%data )

 Delete DNS (A/AAAA) record for client domain alternative URL

 Param hash \%data Domain data
 Return int 0 on success, other on failure

=cut

sub postdeleteDmn
{
    my ( $self, $data ) = @_;

    return 0 unless $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes';

    $self->{'named'}->deleteSub( {
        PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
        DOMAIN_NAME        => "$data->{'DOMAIN_TYPE'}$data->{'DOMAIN_ID'}.$::imscpConfig{'BASE_SERVER_VHOST'}"
    } );
}

=item postaddSub( \%data )

 Add DNS (A/AAAA) record for client subdomain alternative URL

 Param hash \%data Subdomain data
 Return int 0 on success, other on failure

=cut

sub postaddSub
{
    my ( $self, $data ) = @_;

    return 0 unless $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes';

    $self->{'named'}->addSub( {
        PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
        DOMAIN_NAME        => "$data->{'DOMAIN_TYPE'}$data->{'DOMAIN_ID'}.$::imscpConfig{'BASE_SERVER_VHOST'}",
        MAIL_ENABLED       => FALSE,
        DOMAIN_IP          => $data->{'BASE_SERVER_PUBLIC_IP'}
    } );
}

=item postdeleteSub( \%data )

 Delete DNS (A/AAAA) record for client subdomain alternative URL

 Param hash \%data Subdomain data
 Return int 0 on success, other on failure

=cut

sub postdeleteSub
{
    my ( $self, $data ) = @_;

    return 0 unless $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes';

    $self->{'named'}->deleteSub( {
        PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
        DOMAIN_NAME        => "$data->{'DOMAIN_TYPE'}$data->{'DOMAIN_ID'}.$::imscpConfig{'BASE_SERVER_VHOST'}"
    } );
}

=back

=head1 EVENT LISTENERS

=over 4

=item askForClientDomainsAltURLs( $dialog )

 Ask for client domains alternative URLs

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 20 (SKIP), 30 (BACK), 50 (ESC)

=cut

sub askForClientDomainsAltURLs
{
    my ( $dialog ) = @_;

    if ( ::setupGetQuestion( 'BIND_TYPE' ) ne 'master' ) {
        ::setupSetQuestion( 'CLIENT_DOMAIN_ALT_URLS', 'no' );
        return 20;
    }

    my $value = ::setupGetQuestion( 'CLIENT_DOMAIN_ALT_URLS' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'client_domains_alt_urls', 'all' ] ) || !isStringInList( $value, 'yes', 'no' ) ) {
        my $rs = $dialog->yesno( <<'EOF', $value eq 'no', TRUE );

Do you want to enable the alternative URLs for the client domains?

Alternative URLs make the clients able to access their websites through control panel subdomains such as dmn1.panel.domain.tld.

This feature is useful for clients who have not yet updated their DNS so that their domain name points to the IP address of the server that has been assigned to them. 
EOF
        return $rs unless $rs < 30;
        $value = $rs ? 'no' : 'yes'
    }

    ::setupSetQuestion( 'CLIENT_DOMAIN_ALT_URLS', $value );
    0;
}

=item beforeHttpdBuildConfFile( \$cfgTpl, $filename, \%data, $options )

 Add server alias for client domain/subdomain alternative URL in httpd vhost file

 Param scalarref Httpd configuration file content
 Param string Httpd configuration filename
 Param hashref \%data Domain data as provided by domain modules
 Param hashref \%option Options
 Return int 0

=cut

sub beforeHttpdBuildConfFile
{
    my ( $self, undef, $filename ) = @_;

    return 0 unless $filename eq 'domain.tpl' && $::imscpConfig{'CLIENT_DOMAIN_ALT_URLS'} eq 'yes';

    my $serverData = $self->{'httpd'}->getData();
    my $alias = "$serverData->{'DOMAIN_TYPE'}$serverData->{'DOMAIN_ID'}.$::imscpConfig{'BASE_SERVER_VHOST'}";

    $self->{'httpd'}->setData( {
        SERVER_ALIASES => length $serverData->{'SERVER_ALIASES'} ? $serverData->{'SERVER_ALIASES'} . ' ' . $alias : $alias
    } );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return Package::ClientDomainsAltURLs

=cut

sub _init
{
    my ( $self ) = @_;

    iMSCP::EventManager->getInstance()->register( 'beforeHttpdBuildConfFile', sub { $self->beforeHttpdBuildConfFile( @_ ); } );
    $self->{'httpd'} = lazy {
        require Servers::httpd;
        Servers::httpd->factory();
    };
    $self->{'named'} = lazy {
        require Servers::named;
        Servers::named->factory();
    };
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
