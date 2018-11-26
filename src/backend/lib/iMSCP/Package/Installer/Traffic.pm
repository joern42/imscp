=head1 NAME

 iMSCP::Package::Installer::Traffic - i-MSCP Traffic package

=cut

package iMSCP::Package::Installer::Traffic;

use strict;
use warnings;
use iMSCP::Server::cron;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 i-MSCP Traffic package.
 
 Setup cron tasks for both server and customer traffic accounting

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $cronServer = iMSCP::Server::cron->factory();
    my $rs = $cronServer->addTask( {
        TASKID  => __PACKAGE__ . ' - server traffic',
        MINUTE  => '0,30',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => "nice -n 10 ionice -c2 -n5 $::imscpConfig{'SHARE_DIR'}/iMSCP/Package/Installer/Traffic/bin/imscp-srv-traff "
            . "> $::imscpConfig{'LOG_DIR'}/imscp-srv-traff.log 2>&1"
    } );
    $rs ||= $cronServer->addTask( {
        TASKID  => __PACKAGE__ . ' - customers traffic',
        MINUTE  => '0,30',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => "nice -n 10 ionice -c2 -n5 $::imscpConfig{'SHARE_DIR'}/iMSCP/Package/Installer/Traffic/bin/imscp-vrl-traff "
            . "> $::imscpConfig{'LOG_DIR'}/imscp-vrl-traff.log 2>&1"
    } );
}

=item uninstall( )

 See iMSCP::Uninstaller::AbstractActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $cronServer = iMSCP::Server::cron->factory();

    my $rs = $cronServer->deleteTask( { TASKID => __PACKAGE__ . ' - server traffic' } );
    $rs ||= $cronServer->deleteTask( { TASKID => __PACKAGE__ . ' - customers traffic' } );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
