=head1 NAME

 iMSCP::JobQueueManager - i-MSCP job queue manager

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

package iMSCP::JobQueueManager;

use strict;
use warnings;
use iMSCP::Boolean;
use iMSCP::Database;
use iMSCP::Debug qw/ debug newDebug endDebug /;
use iMSCP::EventManager;
use iMSCP::Modules;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP job queue manager.

=head1 PUBLIC METHODS

=over 4

=item processJobs

 Process all enqueued jobs

 Return void die on failure

=cut

sub processJobs
{
    my ( $self ) = @_;

    iMSCP::EventManager->getInstance( 'beforeProcessJobs' );

    my $sth = $self->{'_dbh'}->prepare( "SELECT * FROM imscp_job WHERE state = 'scheduled' ORDER BY jobID, userID, moduleName, moduleGroup" );
    $sth->execute();

    # FIXME: Should we fork or sth like this to allow multiprocessing on a per job group basis?

    while ( my $job = $sth->fetchrow_hashref() ) {
        # Ignore job if it is part of a job group with failure state
        next if $self->{'_failureByServerJobGroup'}->{$job->{'serverID'}}->{$job->{'userID'}};

        if ( $job->{'serverID'} == $self->{'_serverID'} ) {
            $this->processJob( $job );
            next;
        }

        unless ( $self->{'_notifiedRemoteServers'}->{$job->{'serverID'}} ) {
            $self->{'_notifiedRemoteServers'}->{$job->{'serverID'}} = $self->_notifyRemoteNode( $job->{'serverID'} );
        }

    }

    iMSCP::EventManager->getInstance( 'afterProcessJobs' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::DbTasksProcessor or die on failure

=cut

sub _init
{
    my ( $self ) = @_;

    # Load all modules
    iMSCP::Modules->getInstance();

    $self->{'_serverID'} = $::imscpConfig{'SERVER_ID'};
    $self->{'_dbh'} = iMSCP::Database->getInstance();
    $self->{'_notifiedRemoteServers'} = {};
    $self->{'_failureByServerJobGroup'} = {};
    $self;
}

=item _processJob( $job )

 Process the given job

 Param hashref \%job Job data
 Return void, die on failure

=cut

sub _processJob
{
    my ( $self, $job ) = @_;

    debug( sprintf( 'Processing %s job (ID %s) ', $module, $job->{'jobID'} ));
    newDebug( $job->{'moduleName'} . ( $perJobLogFile ? "_${name}" : '' ) . '.log' );

    eval {
        iMSCP::EventManager->getInstance( 'beforeProcessJob', $job );
        "iMSCP::Modules::$job->{'moduleName'}"->new()->processEntity( $job->{'objectID'}, $job->{'moduleData'} );
        iMSCP::EventManager->getInstance( 'afterProcessJob', $job );
        $self->{'_dbh'}->do( "UPDATE imscp_job SET state = 'processed', error = NULL WHERE jobID = ?", undef, $job->{'jobID'} );
    };
    if ( $@ ) {
        eval {
            $self->{'_failureByServerJobGroup'}->{$job->{'serverID'}}->{$job->{'userID'}} = TRUE;
            $self->{'_dbh'}->begin_work();
            $self->{'_dbh'}->do( "UPDATE imscp_job SET state = 'pending', error = ?", undef, $@ || 'Unknown error' );
            # Also update state of all other jobs inside that job group
            $self->{'_dbh'}->do(
                "UPDATE imscp_job SET state = 'pending', error('Pending due to previous job failure') WHERE jobID <> ? AND userID = ? AND moduleGroup = ?",
                undef,
                $job->{'jobID'},
                $job->{'userID'},
                $job->{'moduleGroup'}
            );
            $self->{'_dbh'}->commit();
        };
        if ( $@ ) {
            $self->{'_dbh'}->rollback();
            die;
        }
    }

    endDebug();
}

=item _notifyRemoteServer

 Notify a remote server (node) for a new job to process

 Return boolean TRUE if the remote server has been notified, FALSE otherwise
=cut

sub _notifyRemoteServer
{
    my ( $self ) = @_;

    # TODO send request to remote server (node) -- Need to write the new daemon first...
    1;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
