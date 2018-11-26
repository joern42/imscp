=head1 NAME

 iMSCP::Package::Installer::LogCleanup - i-MSCP LogCleanup package

=cut

package iMSCP::Package::Installer::LogCleanup;

use strict;
use warnings;
use iMSCP::Server::cron;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 i-MSCP LogCleanup package.
 
 Setup cron task for cleanup of i-MSCP log files

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
        MINUTE  => '@weekly',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => "find $::imscpConfig{'LOG_DIR'} -type f -mtime +7 -exec rm -- {} \+"
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
