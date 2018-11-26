=head1 NAME

 iMSCP::Modules::CustomDNS - Module for processing of group of custom DNS entities

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

package iMSCP::Modules::CustomDNS;

use strict;
use warnings;
use Text::Balanced qw/ extract_multiple extract_delimited /;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of group of custom DNS entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ( $self ) = @_;

    'CustomDNS';
}

=item handleEntity( $entityId )

 See iMSCP::Modules::Abstract::handleEntity()

=cut

sub handleEntity
{
    my ( $self, $entityId ) = @_;

    my ( $domainId, $aliasId ) = split ';', $entityId;

    defined $domainId && defined $aliasId or die( 'Bad input data' );

    eval {
        $self->_loadEntityData( $domainId, $aliasId );
        $self->_add()
    };
    if ( $@ ) {
        $self->{'_dbh'}->do(
            "UPDATE domain_dns SET domain_dns_status = ? WHERE domain_id = ? AND alias_id = ? AND domain_dns_status <> 'disabled'",
            undef, $@, $domainId, $aliasId
        );
        return;
    }

    eval {
        $self->{'_dbh'}->begin_work();
        $self->{'_dbh'}->do(
            "
                UPDATE domain_dns
                SET domain_dns_status = IF(
                    domain_dns_status = 'todisable', 'disabled', IF(domain_dns_status NOT IN('todelete', 'disabled'), 'ok', domain_dns_status)
                )
                WHERE domain_id = ?
                AND alias_id = ?
            ",
            undef, $domainId, $aliasId
        );
        $self->{'_dbh'}->do(
            "DELETE FROM domain_dns WHERE domain_id = ? AND alias_id = ? AND domain_dns_status = 'todelete'", undef, $domainId, $aliasId,
        );
        $self->{'_dbh'}->commit();
    };
    if ( $@ ) {
        $self->{'_dbh'}->rollback();
        die;
    }
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadEntityData( $domainId )

 See iMSCP::Modules::Abstract::_loadEntityData()

=cut

sub _loadEntityData
{
    my ( $self, $domainId ) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref( 'SELECT domain_name AS zone FROM domain WHERE domain_id = ?', undef, $domainId);
    %{ $row } or die( sprintf( 'Data not found for custom DNS records group %d', $domainId ));
    $self->{'_data'}->{'ZONE'} = $row->{'zone'};
    undef $row;

    my $rows = $self->{'_dbh'}->selectall_arrayref(
        "
            SELECT domain_dns, domain_class, domain_type, domain_text, domain_dns_status
            FROM domain_dns
            WHERE domain_id = ?
            AND domain_dns_status NOT IN('todelete', 'todisable', 'disabled')
        ",
        undef, $domainId, $aliasId
    );

    return unless @{ $rows };

    # 1. For TXT/SPF records, split data field into several
    #    <character-string>s when <character-string> is longer than 255
    #    bytes. See: https://tools.ietf.org/html/rfc4408#section-3.1.3
    my @dnsRecords;
    for $row ( @{ $rows } ) {
        if ( $row->[2] eq 'TXT' || $row->[2] eq 'SPF' ) {
            # Turn line-breaks into whitespaces
            $row->[3] =~ s/\R+/ /g;

            # Remove leading and trailing whitespaces
            $row->[3] =~ s/^\s+//;
            $row->[3] =~ s/\s+$//;

            # Make sure to work with quoted <character-string>
            $row->[3] = qq/"$row->[3]"/ unless $row->[3] =~ /^".*"$/;

            # Split data field into several <character-string>s when
            # <character-string> is longer than 255 bytes, excluding delimiters.
            # See: https://tools.ietf.org/html/rfc4408#section-3.1.3
            if ( length $row->[3] > 257 ) {
                # Extract all quoted <character-string>s, excluding delimiters
                $_ =~ s/^"(.*)"$/$1/ for my @chunks = extract_multiple( $row->[3], [ sub { extract_delimited( $row->[0], '"' ) } ], undef, 1 );
                $row->[3] = join '', @chunks if @chunks;
                undef @chunks;

                for ( my $i = 0, my $length = length $row->[3]; $i < $length; $i += 255 ) {
                    push( @chunks, substr( $row->[3], $i, 255 ));
                }

                $row->[3] = join ' ', map ( qq/"$row"/, @chunks );
            }
        }

        push @dnsRecords, [ ( @{ $row } )[0 .. 3] ];
    }

    $self->{'_data'}->{'DNS_RECORDS'} = [ @dnsRecords ];
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
