=head1 NAME

 iMSCP::Package::Installer::PostfixAddon::Postscreen - Postfix postscreen server

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

package iMSCP::Package::Installer::PostfixAddon::Postscreen;

use strict;
use warnings;
use iMSCP::DistPackageManager;
use iMSCP::File;
use Servers::mta;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 The Postfix postscreen server provides additional protection against mail
 server overload. One postscreen process handles multiple inbound SMTP
 connections, and decides which clients may talk to a Postfix SMTP server process.
 By keeping spambots away, postscreen leaves more SMTP server processes available
 for legitimate clients, and delays the onset of server overload conditions.

 Site: http://www.postfix.org/POSTSCREEN_README.html

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_setupAccessList();
    return $rs if $rs;

    my $postfix = iMSCP::Servers::Mta->factory();
    my $file = iMSCP::File->new( filename => $postfix->{'config'}->{'POSTFIX_MASTER_CONF_FILE'} );
    my $fileC = $file->getAsRef();
    return 1 unless defined $fileC;

    ${ $fileC } = <<"EOF";

# @{[ __PACKAGE__ ]} begin
smtp      inet  n       -       y       -       1       postscreen
smtpd     pass  -       -       y       -       -       smtpd
tlsproxy  unix  -       -       y       -       0       tlsproxy
dnsblog   unix  -       -       y       -       0       dnsblog
# @{[ __PACKAGE__ ]} ending

EOF

    $rs = $file->save();
    $rs ||= $postfix->postconf( (
        postscreen_greet_action              => {
            action => 'replace',
            values => [ $self->{'config'}->{'GREET_ACTION'} ]
        },
        postscreen_dnsbl_sites               => {
            action => 'replace',
            values => [ split ',', $self->{'config'}->{'DNSBL_SITES'} ]
        },
        postscreen_dnsbl_threshold           => {
            action => 'replace',
            values => [ $self->{'config'}->{'DNSBL_THRESHOLD'} ]
        },
        postscreen_dnsbl_action              => {
            action => 'replace',
            values => [ $self->{'config'}->{'DNSBL_ACTION'} ]
        },
        postscreen_access_list               => {
            action => 'replace',
            values => [ split ',', $self->{'config'}->{'ACCESS_LIST'} ]
        },
        postscreen_blacklist_action          => {
            action => 'replace',
            values => [ $self->{'config'}->{'BLACKLIST_ACTION'} ]
        },
        postscreen_dnsbl_whitelist_threshold => {
            action => 'replace',
            values => [ $self->{'config'}->{'DNSBL_WHITElIST_THRESHOLD'} ]
        }
    ));
}

=item uninstall( )

 See iMSCP::Uninstaller::AbstractActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    for my $list ( split ',', @{ $self->{'config'}->{'POSTSCREEN_ACCESS_LIST'} } ) {
        next unless index( $list, 'cidr:' ) == 0;

        my $rs = iMSCP::File->new( filename => $list =~ s/^cidr://r )->delFile();
        return $rs if $rs;
    }

    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setupAccessList( )

 Setup access list

 Return int 0 on success, other on failure

=cut

sub _setupAccessList
{
    my ( $self ) = @_;

    for my $list ( split ',', @{ $self->{'config'}->{'ACCESS_LIST'} } ) {
        next unless index( $list, 'cidr:' ) == 0;

        my $file = iMSCP::File->new( filename => $list =~ s/^cidr://r );
        next if -f "$file";

        my $rs = $file->set( <<'EOF' );
# For more information please check man postscreen or
# http://www.postfix.org/postconf.5.html#postscreen_access_list
#
# Rules are evaluated in specified order.
# Blacklist 192.168.* except 192.168.0.1
# 192.168.0.1         permit
# 192.168.0.0/16      reject
EOF
        $rs ||= $file->save();
        $rs ||= $file->mode( 0644 );
        return $rs if $rs;
    }

    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
