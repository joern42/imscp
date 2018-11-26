=head1 NAME

 iMSCP::Dialog - Proxy to iMSCP::Dialog::FrontEndInterface implementations

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

package iMSCP::Dialog;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Getopt;
use parent 'iMSCP::Dialog::FrontEndInterface';

=head1 DESCRIPTION

 Proxy to iMSCP::Dialog::FrontEndInterface implementations

=head1 PUBLIC METHODS

=over 4

=item executeDialogs( \@dialogs )

 Execute the given stack of dialogs

 Implements a simple state machine (backup capability)
  - Dialog subroutines SHOULD not fail. However, they can die() on unrecoverable errors
  - On success, dialog subroutines MUST return 0
  - When skipped, dialog subroutines MUST return 20
  - When back up, dialog subroutines MUST return 30

 @param $dialogs \@dialogs Dialogs stack
 @return int 0 (SUCCESS), 20 (SKIP), 30 (BACK)

=cut

my $ExecuteDialogsFirstCall = TRUE;
my $ExecuteDialogsBackupContext = FALSE;

sub executeDialogs
{
    my ( $self, $dialogs ) = @_;

    ref $dialogs eq 'ARRAY' or die( 'Invalid $dialog parameter. Expect an array of dialog subroutines.' );

    my $dialOuter = $ExecuteDialogsFirstCall;
    $ExecuteDialogsFirstCall = FALSE if $dialOuter;

    my ( $ret, $state, $countDialogs ) = ( 0, 0, scalar @{ $dialogs } );
    while ( $state < $countDialogs ) {
        local $self->{'_opts'}->{'nocancel'} = $state || !$dialOuter ? undef : '' if exists $self->{'_opts'}->{'nocancel'};
        $ret = $dialogs->[$state]->( $self );
        last if $ret == 30 && $state == 0;

        if ( $state && ( $ret == 30 || $ret == 20 && $ExecuteDialogsBackupContext ) ) {
            $ExecuteDialogsBackupContext = TRUE if $ret == 30;
            $state--;
            next;
        }

        $ExecuteDialogsBackupContext = FALSE if $ExecuteDialogsBackupContext;
        $state++;
    }

    $ret;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Common::Singleton::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'frontEnd'} = do {
        if ( iMSCP::Getopt->noninteractive ) {
            require iMSCP::Dialog::NonInteractive;
            iMSCP::Dialog::NonInteractive->getInstance();
        } else {
            # Dialog frontEnd are loaded in order of preference, unless the
            # user forced specific frontEnd type through environment variables
            local $@;
            eval {
                die if $ENV{'IMSCP_DIALOG_FORCE_DIALOG'};
                require iMSCP::Dialog::Whiptail;
                iMSCP::Dialog::Whiptail->getInstance();
            } or do {
                require iMSCP::Dialog::Dialog;
                iMSCP::Dialog::Dialog->getInstance();
            }
        }
    };

    # Allow localization of dialog frontEnd options through this object
    $self->{'_opts'} = $self->{'frontEnd'}->{'_opts'} if exists $self->{'frontEnd'}->{'_opts'};
}

=item AUTOLOAD

 Proxy implementation

=cut

sub AUTOLOAD
{
    ( my $method = $iMSCP::Dialog::AUTOLOAD ) =~ s/.*:://;

    no strict 'refs';
    *{ $iMSCP::Dialog::AUTOLOAD } = sub {
        shift; # Shift this object as we do not want pass it to proxied object
        __PACKAGE__->getInstance()->{'frontEnd'}->$method( @_ );
    };
    goto &{ $iMSCP::Dialog::AUTOLOAD };
}

=item DESTROY

 Needed due to autoloading

=cut

sub DESTROY
{

}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
