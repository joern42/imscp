=head1 NAME

 iMSCP::Package::Installer::Traffic - i-MSCP Traffic package

=cut

package iMSCP::Package::Installer::Traffic;

use strict;
use warnings;
use Servers::cron;
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

    $self->_addCronTasks();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _addCronTasks( )

 Add cron tasks

 Return int 0 on success, other on failure

=cut

sub _addCronTasks
{
    my ( $self ) = @_;

    my $cron = Servers::cron->factory();
    my $rs = $cron->addTask( {
        TASKID  => __PACKAGE__ . ' - server traffic',
        MINUTE  => '0,30',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => "nice -n 10 ionice -c2 -n5 $::imscpConfig{'PACKAGES_DIR'}/Installer/Traffic/bin/imscp-srv-traff "
            . "> $::imscpConfig{'LOG_DIR'}/imscp-srv-traff.log 2>&1"
    } );
    $rs ||= $cron->addTask( {
        TASKID  => __PACKAGE__ . ' - customer traffic',
        MINUTE  => '0,30',
        USER    => $::imscpConfig{'ROOT_USER'},
        COMMAND => "nice -n 10 ionice -c2 -n5 $::imscpConfig{'PACKAGES_DIR'}/Installer/Traffic/bin/imscp-vrl-traff "
            . "> $::imscpConfig{'LOG_DIR'}/imscp-srv-traff.log 2>&1"
    } );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
