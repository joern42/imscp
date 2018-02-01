=head1 NAME

 iMSCP::Config - i-MSCP configuration file handler

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by Laurente Declercq <l.declercq@nuxwin.com>
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

package iMSCP::Config;

use strict;
use warnings;
use Carp qw / croak /;
use 5.012;
use Fcntl 'O_RDWR', 'O_CREAT', 'O_RDONLY';
use Tie::File;
use parent 'iMSCP::Common::Object';

=head1 DESCRIPTION

 Provides access to various i-MSCP configuration files through tied hash

=head1 PUBLIC METHODS

=over 4

=item flush( )

 Write data immediately in file

=cut

sub flush
{
    my $tiedArr = tied @{$_[0]->{'_file'}};

    return 0 if $_[0]->{'readonly'} || !( $tiedArr->{'defer'} || $tiedArr->{'autodeferring'} );

    $tiedArr->flush();
}

=back

=head1 PRIVATE METHODS

=over 4

=item TIEHASH( )

 Constructor. Called by the tie command

 Required arguments for tie command
  - fileName: Configuration file path
 Optional arguments for tie command
  - nocreate: Do not create file if it doesn't already exist, die instead
  - nodeferring: Writes in file immediately instead of deffering writing (Only relevant in write mode)
  - nocroak: Do not croak when accessing to an non-existent configuration parameter
  - nospaces: Do not add spaces around configuration parameter name/value separator
  - readonly: Sets a read-only access on the configuration file
  - temporary: Enable temporary overriding of configuration values (changes are not persistent)

  Return iMSCP::Config, die on failure
=cut

sub TIEHASH
{
    my ($class, @argv) = @_;

    my $self = bless { @argv && ref $argv[0] eq 'HASH' ? %{$argv[0]} : @argv }, $class;
    my $mode = $self->{'nocreate'} ? ( $self->{'readonly'} ? O_RDONLY : O_RDWR ) : ( $self->{'readonly'} ? O_RDONLY : O_RDWR | O_CREAT );
    my $tiedArr = tie @{$self->{'_file'}}, 'Tie::File', $self->{'fileName'}, memory => 10_000_000, mode => $mode or die(
        sprintf( "Couldn't tie %s file: %s", $self->{'fileName'}, $! )
    );
    $tiedArr->defer unless $self->{'nodeferring'} || $self->{'readonly'};

    while ( my ($recordIdx, $value) = each( @{$self->{'_file'}} ) ) {
        next unless $value =~ /^([^#\s=]+)\s*=\s*(.*)/o;
        $self->{'_entries'}->{$1} = $2;
        $self->{'_records_map'}->{$1} = $recordIdx;
    }

    $self
}

=item STORE( )

 Store the given configuration parameter

=cut

sub STORE
{
    !$_[0]->{'readonly'} || $_[0]->{'temporary'} or croak( sprintf( "Couldn't store the %s parameter: tied hash is readonly", $_[1] ));

    my $v = defined $_[2] ? $_[2] : ''; # A configuration parameter cannot be undefined.

    if ( !$_[0]->{'temporary'} && exists $_[0]->{'_entries'}->{$_[1]} ) {
        @{$_[0]->{'_file'}}[$_[0]->{'_records_map'}->{$_[1]}] = $_[0]->{'nospaces'} ? "$_[1]=$v" : "$_[1] = $v";
    } elsif ( !$_[0]->{'temporary'} ) {
        push @{$_[0]->{'_file'}}, $_[0]->{'nospaces'} ? "$_[1]=$v" : "$_[1] = $v";
        $_[0]->{'_records_map'}->{$_[1]} = $#{$_[0]->{'_file'}};

    }

    $_[0]->{'_entries'}->{$_[1]} = $v;
}

=item FETCH

 Fetch the given configuration parameter

=cut

sub FETCH
{
    return $_[0]->{'_entries'}->{$_[1]} if exists $_[0]->{'_entries'}->{$_[1]};

    $_[0]->{'nocroak'} or croak( sprintf( 'Accessing a non-existing parameter: %s', $_[1] ));
    ''; # A configuration parameter cannot be undefined. 
}

=item FIRSTKEY

 Return the first configuration parameter

=cut

sub FIRSTKEY
{
    scalar keys %{$_[0]->{'_entries'}}; # reset iterator
    each( %{$_[0]->{'_entries'}} );
}

=item NEXTKEY( )

 Return the next configuration parameter

=cut

sub NEXTKEY
{
    each( %{$_[0]->{'_entries'}} );
}

=item EXISTS

 Verify that the given configuration parameter exists

=cut

sub EXISTS
{
    exists $_[0]->{'_entries'}->{$_[1]};
}

=item DELETE

 Delete the given configuration parameter

=cut

sub DELETE
{
    !$_[0]->{'readonly'} || $_[0]->{'temporary'} or croak(
        sprintf( "Couldn't delete the %s parameter: tied hash is readonly", $_[1] )
    );

    unless ( $_[0]->{'temporary'} || !exists $_[0]->{'_records_map'}->{$_[1]} ) {
        splice @{$_[0]->{'_file'}}, $_[0]->{'_records_map'}->{$_[1]}, 1;

        # Rebuild records map
        # FIXME Find a faster way to rebuild records map without having to read the file again
        undef( %{$_[0]->{'_records_map'}} );
        while ( my ($recordIdx, $value) = each( @{$_[0]->{'_file'}} ) ) {
            next unless $value =~ /^([^#\s=]+)\s*=\s*(.*)/o;
            $_[0]->{'_records_map'}->{$1} = $recordIdx;
        }
    }

    delete $_[0]->{'_entries'}->{$_[1]};
}

=item CLEAR( )

 Clear all configuration parameters

=cut

sub CLEAR
{
    undef @{$_[0]->{'_file'}}; # Clear full content from file
    undef %{$_[0]->{'_records_map'}}; # Clear records map
    undef %{$_[0]->{'_entries'}}; # Clear entries
}

=item SCALAR( )

 Returns what evaluating the hash in scalar context yields

=cut

sub SCALAR
{
    scalar %{$_[0]->{'_entries'}};
}

=item DESTROY( )

 Destroy

=cut

sub DESTROY
{
    untie( @{$_[0]->{'_file'}} );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
