=head1 NAME

 iMSCP::Package::Installer::AccountsSuspension - i-MSCP Account suspension package

=cut

package iMSCP::Package::Installer::AccountsSuspension;

use strict;
use warnings;
use iMSCP::Server::cron;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 i-MSCP AccountsSuspension package.
 
 Setup cron task for suspension of expired accounts

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    iMSCP::Server::cron->factory()->addTask( {
        TASKID  => __PACKAGE__,
        MINUTE  => '@daily',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => "nice -n 10 ionice -c2 -n5 $::imscpConfig{'SHARE_DIR'}iMSCP/Package/Installer/AccountsSuspension/bin/imscp-accounts-suspension "
            . "> $::imscpConfig{'LOG_DIR'}/imscp-account-suspension.log 2>&1"
    } );
}

=item uninstall( )

 See iMSCP::Uninstaller::AbstractActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    iMSCP::Server::cron->factory()->deleteTask( { TASKID => __PACKAGE__ } );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
