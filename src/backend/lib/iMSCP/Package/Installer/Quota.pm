=head1 NAME

 iMSCP::Package::Installer::Traffic - i-MSCP Quota package

=cut

package iMSCP::Package::Installer::Quota;

use strict;
use warnings;
use iMSCP::cron;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 i-MSCP Quota package.
 
 Setup cron task for quota accounting

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
        COMMAND => "nice -n 10 ionice -c2 -n5 $::imscpConfig{'SHARE_DIR'}/iMSCP/Package/Installer/Quota/bin/imscp-dsk-quota "
            . "> $::imscpConfig{'LOG_DIR'}/imscp-dsk-quota.log 2>&1"
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
