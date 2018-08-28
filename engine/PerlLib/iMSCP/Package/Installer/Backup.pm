=head1 NAME

 iMSCP::Package::Installer::Backup - i-MSCP backup

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

package iMSCP::Package::Installer::Backup;

use strict;
use warnings;
use Class::Autouse qw/ :nostats Servers::cron /;
use iMSCP::Boolean;
use iMSCP::Dialog::InputValidation qw/ isOneOfStringsInList isStringInList /;
use parent 'iMSCP::Package::Abstract';

=head1 DESCRIPTION

 i-MSCP backup.

=head1 PUBLIC METHODS

=over 4

=item registerInstallerDialogs( $dialogs )

 See iMSCP::AbstractInstallerActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    push @{ $dialogs },
        sub { $self->_askForCpBackup( @_ ) },
        sub { $self->_askForClientsBackup( @_ ) };
    0;
}

=item install( )

 See iMSCP::AbstractInstallerActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $cronServer = Servers::cron->factory();

    if ( ::setupGetQuestion( 'BACKUP_IMSCP' ) eq 'yes' ) {
        # Cron task for backup of i-MSCP configuration files and database
        my $rs = $cronServer->addTask( {
            TASKID  => __PACKAGE__ . '::iMSCP::Backup',
            MINUTE  => '@daily',
            COMMAND => "$::imscpConfig{'BACKUP_ROOT_DIR'}/imscp.pl > $::imscpConfig{'LOG_DIR'}/imscp-backup-imscp.log 2>&1"
        } );

        # Cron task for deletion of i-MSCP backup files
        $rs ||= $cronServer->addTask( {
            TASKID  => __PACKAGE__ . '::iMSCP::Cleanup',
            MINUTE  => '@weekly',
            COMMAND => "find $::imscpConfig{'BACKUP_FILE_DIR'} -type f -mtime +7 -exec rm -- {} \+"
        } );
        return $rs if $rs;
    }

    if ( ::setupGetQuestion( 'BACKUP_DOMAINS' ) eq 'yes' ) {
        # Cron task for backup of client data
        my $rs = $cronServer->addTask( {
            TASKID  => __PACKAGE__ . '::Clients::Backup',
            MINUTE  => length $::imscpConfig{'BACKUP_MINUTE'} ? $::imscpConfig{'BACKUP_MINUTE'} : 40,
            HOUR    => length $::imscpConfig{'BACKUP_HOUR'} ? $::imscpConfig{'BACKUP_HOUR'} : 23,
            COMMAND => "nice -n 10 ionice -c2 -n5 perl $::imscpConfig{'BACKUP_ROOT_DIR'}/clients.pl > "
                . "$::imscpConfig{'LOG_DIR'}/imscp-backup-all.log 2>&1"
        } );
        return $rs if $rs;
    }
    
    # Cron task for deletion of server backup files
    $cronServer->addTask( {
        TASKID  => __PACKAGE__ . '::Servers::Cleanup',
        MINUTE  => '@weekly',
        COMMAND => "find $::imscpConfig{'CONF_DIR'}/*/backup -type f -mtime +7 -regextype sed -regex '.*/.*[0-9]\{10\}\$' -exec rm -- {} \+"
    } );

    0;
}

=item uninstall( )

 See iMSCP::AbstractUninstallerActions::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    my $cronServer = Servers::cron->factory();

    my $rs = $cronServer->deleteTask( { TASKID => __PACKAGE__ . '::iMSCP' } );
    $rs ||= $cronServer->deleteTask( { TASKID => __PACKAGE__ . '::Client' } );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _askForCpBackup( $dialog )

 Ask for control panel backup

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForCpBackup
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'BACKUP_IMSCP' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'cp_backup', 'backup', 'all' ] ) || !isStringInList( $value, 'yes', 'no' ) ) {
        my $rs = $dialog->yesno( <<'EOF', $value eq 'no', TRUE );

Do you want enable daily backup for the control panel (database and configuration files)?
EOF
        return $rs unless $rs < 30;
        $value = $rs ? 'no' : 'yes'
    }

    ::setupSetQuestion( 'BACKUP_IMSCP', $value );
    0;
}

=item _askForClientsBackup( $dialog )

 Ask for clients backup

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForClientsBackup
{
    my ( $self, $dialog ) = @_;

    my $value = ::setupGetQuestion( 'BACKUP_DOMAINS' );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'client_backup', 'backup', 'all' ] ) || !isStringInList( $value, 'yes', 'no' ) ) {
        my $rs = $dialog->yesno( <<'EOF', $value eq 'no', TRUE );

Do you want to activate the backup feature for the clients?
EOF
        return $rs unless $rs < 30;
        $value = $rs ? 'no' : 'yes'
    }

    ::setupSetQuestion( 'BACKUP_DOMAINS', $value );
    0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
