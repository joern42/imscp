=head1 NAME

 iMSCP::Package::WebsitesAltURLs - i-MSCP Alternative URLs fo client Websites

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

package iMSCP::Package::WebsitesAltURLs;

use strict;
use warnings;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isOneOfStringsInList isStringInList /;
use Class::Autouse qw/ :nostat Servers::httpd Servers::named /;
use iMSCP::Boolean;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 Alternative URLs for client websites.
 
 Alternative URLs make the clients able to access their Websites (domains)
 through a control panel subdomains such as dmn1.panel.domain.tld.

 This feature is useful for clients who have not yet updated their DNS so that
 their domain name points to the IP address of the server that has been
 assigned to them.

=head1 PUBLIC METHODS

=over 4

=item registerInstallerDialogs( $dialogs )

 See iMSCP::AbstractInstallerActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    push @{ $dialogs }, \&_askForClientWebsitesAltURLs;
    0;
}

=item postaddDmn( \%data )

 See iMSCP::Modules::AbstractActions::postaddDmn()

=cut

sub postaddDmn
{
    my ( $self, $data ) = @_;

    $self->_addDnsRecord( $data );
}

=item postdeleteDmn( \%data )

 See iMSCP::Modules::AbstractActions::postaddDmn()

=cut

sub postdeleteDmn
{
    my ( $self, $data ) = @_;

    $self->_deleteDnsRecord( $data );
}

=item postaddSub( \%data )

 See iMSCP::Modules::AbstractActions::postaddDmn()

=cut

sub postaddSub
{
    my ( $self, $data ) = @_;

    $self->_addDnsRecord( $data );
}

=item postDeleteSub( \%data )

 See iMSCP::Modules::AbstractActions::postaddDmn()

=cut

sub postDeleteSub
{
    my ( $self, $data ) = @_;

    $self->_deleteDnsRecord( $data );
}

=back

=head1 EVENT LISTENERS

=over 4

=item addServerAlias( \$cfgTpl, $filename, \%data, $options )

 Add server alias for client domain/subdomain alternative URL in httpd vhost file

 Param scalarref Httpd configuration file content
 Param string Httpd configuration filename
 Param hashref \%data Domain data as provided by domain modules
 Param hashref \%option Options
 Return int 0

=cut

sub _addServerAlias
{
    my ( $self, undef, $filename ) = @_;

    return 0 unless $filename eq 'domain.tpl' && $::imscpConfig{'WEBSITE_ALT_URLS'} eq 'yes';

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

 See iMSCP::Package::Abstract::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->SUPER::_init();
    $self->{'named'} = Servers::named->factory();
    $self->{'httpd'} = Servers::httpd->factory();
    $self->{'eventManager'}->getInstance()->register( 'beforeHttpdBuildConfFile', sub { $self->_addServerAlias( @_ ); } );
    $self;
}

=item _addDnsRecord( \%data )

 Add DNS (A/AAAA) record for client website alternative URL

 Param hash \%data Subdomain data
 Return int 0 on success, other on failure

=cut

sub _addDnsRecord
{
    my ( $self, $data ) = @_;

    return 0 unless $::imscpConfig{'WEBSITE_ALT_URLS'} eq 'yes';

    $self->{'named'}->addSub( {
        PARENT_DOMAIN_NAME => $::imscpConfig{'BASE_SERVER_VHOST'},
        DOMAIN_NAME        => "$data->{'DOMAIN_TYPE'}$data->{'DOMAIN_ID'}.$::imscpConfig{'BASE_SERVER_VHOST'}",
        DOMAIN_IP          => $data->{'DOMAIN_IP'},
        MAIL_ENABLED       => FALSE
    } );
}

=item _deleteDnsRecord( \%data )

 Delete DNS (A/AAAA) record for client website alternative URL

 Param hash \%data Subdomain data
 Return int 0 on success, other on failure

=cut

sub _deleteDnsRecord
{
    my ( $self, $data ) = @_;

    return 0 unless $::imscpConfig{'WEBSITE_ALT_URLS'} eq 'yes';

    $self->{'named'}->deleteSub( {
        PARENT_DOMAIN_NAME => $::imscpConfig{'SYSTEM_DOMAIN'},
        DOMAIN_NAME        => "$data->{'DOMAIN_TYPE'}$data->{'DOMAIN_ID'}.$::imscpConfig{'BASE_SERVER_VHOST'}"
    } );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _askForClientWebsitesAltURLs( $dialog )

 Ask for client Websites alternative URLs

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForClientWebsitesAltURLs
{
    my ( $dialog ) = @_;

    my $value = ::setupGetQuestion( 'WEBSITE_ALT_URLS' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'website_alt_urls', 'all' ] ) || !isStringInList( $value, 'yes', 'no' ) ) {
        my $rs = $dialog->yesno( <<'EOF', $value eq 'no', TRUE );

Do you want to enable the alternative URLs for the client websites?

Alternative URLs make the clients able to access their websites (domains) through control panel subdomains such as dmn1.panel.domain.tld.

This feature is useful for clients who have not yet updated their DNS so that their domain name points to the IP address of the server that has been assigned to them. 
EOF
        return $rs unless $rs < 30;
        $value = $rs ? 'no' : 'yes'
    }

    ::setupSetQuestion( 'WEBSITE_ALT_URLS', $value );
    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
