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
#use IPC::Shareable ();
use use Parallel::ForkManager;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP job queue manager.

=head1 PUBLIC METHODS

=over 4

=item processJobs

 Process all enqueued jobs

 Return void, die on failure

=cut

sub processJobs
{
    my ( $self ) = @_;

    iMSCP::EventManager->getInstance( 'beforeProcessJobs' );

    # For master server, select all job groups
    # For a node, select only the relevant job groups
    my $sth = $self->{'dbh'}->prepare(
        "
            SELECT userID, serverID, moduleGroup
            FROM imscp_job WHERE " . ( $imscpConfig{'SERVER_TYPE'} eq 'master' ? "serverID = ? AND state = 'scheduled'" : "state = 'scheduled'" ) . "
            GROUP BY userID, serverID, moduleGroup
            ORDER BY jobID ASC
        "
    );
    $sth->execute( $imscpConfig{'SERVER_TYPE'} eq 'master' ? $self->{'serverID'} : ());

    # We process several job groups concurrently to speed up processing.
    # A job group is a set of jobs that are run sequentially in FIFO order.
    my $pm = Parallel::ForkManager->new( $::imscpConfig{'JOB_QUEUE_MANAGER_MAX_WORKERS'} );

    JOB_GROUP:
    while ( my $jobGroup = $sth->fetchrow_hashref() ) {
        next JOB_GROUP if $pm->start();

        debug( sprintf( "Processing %s job group (%d/%d/$$)", $jobGroup->{'moduleGroup'}, $jobGroup->{'userID'}, $jobGroup->{'serverID'} ));
        newDebug( $jobGroup->{'moduleGroup'} . "$jobGroup->{'userID'}-$jobGroup->{'serverID'}-{$$}.log" );

        if ( $jobGroup->{'serverID'} != $self->{'serverID'} ) {
            # The job group doesn't belong to the master server. We need notify the
            # remote node, unless this has been already done.
            unless ( $self->{'notifiedRemoteNodes'}->{$jobGroup->{'serverID'}} ) {
                $self->{'notifiedRemoteNodes'}->{$jobGroup->{'serverID'}} = $self->_notifyRemoteNode( $jobGroup->{'serverID'} );
            }
        } else {
            # Process all job inside the job group
            # We need select all jobs inside the job group, including those
            # that could possibly be in 'pending' state due to a previous
            # failure. Jobs need to be run sequantially. Failures are tracked
            # on a per run basis
            $sth = $self->{'_dbh'}->prepare(
                "SELECT * FROM imscp_job WHERE state <> 'processed' AND userID = ? AND serverID = ? AND moduleGroup = ? ORDER BY jobID ASC"
            );
            $sth->execute( $jobGroup->{'userID'}, $jobGroup->{'serverID'}, $jobGroup->{'moduleGROUP'} );
            while ( my $job = $sth->fetchrow_hashref() ) {
                # Skips the remaining jobs if a failure occurred for that group during that run
                last if $self->{'failuresByJobGroup'}->{$jobGroup->{'userID'}}->{$jobGroup->{'serverID'}}->{$jobGroup->{'moduleGroup'}};
                $this->processJob( $job );
            }
        }

        endDebug();
        $pm->finish;
    }

    $pm->wait_all_children;

    iMSCP::EventManager->getInstance( 'afterProcessJobs' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::JobQueueManager, die on failure

=cut

sub _init
{
    my ( $self ) = @_;

    # Load all modules
    iMSCP::Modules->getInstance();

    $self->{'serverID'} = $::imscpConfig{'SERVER_ID'};
    $self->{'dbh'} = iMSCP::Database->getInstance();
    #tie $self->{'notifiedRemoteNodes'}, 'IPC::Shareable';
    $self->{'notifiedRemoteNodes'} = {};
    $self->{'failuresByJobGroup'} = {};
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

    debug( sprintf( 'Processing %s job (ID %s) ', $job->{'moduleName'}, $job->{'jobID'} ));

    my $stateUpdateFailure = TRUE;
    eval {
        iMSCP::EventManager->getInstance( 'beforeProcessJob', $job );
        "iMSCP::Modules::$job->{'moduleName'}"->new()->processEntity( $job->{'objectID'}, $job->{'moduleData'} );
        iMSCP::EventManager->getInstance( 'afterProcessJob', $job );
        $stateUpdateFailure = FALSE;
        $self->{'_dbh'}->do( "UPDATE imscp_job SET state = 'processed', error = NULL WHERE jobID = ?", undef, $job->{'jobID'} );
    };
    if ( $@ ) {
        die if $stateUpdateFailure;
        eval {
            $self->{'failuresByJobGroup'}->{$jobGroup->{'userID'}}->{$jobGroup->{'serverID'}}->{$jobGroup->{'moduleGroup'}} = TRUE;
            $self->{'_dbh'}->begin_work();
            $self->{'_dbh'}->do( "UPDATE imscp_job SET state = 'pending', error = ?", undef, $@ || 'Unknown error' );
            # Also update state of all other jobs inside that job group
            $self->{'_dbh'}->do(
                "
                    UPDATE imscp_job SET state = 'pending', error('Pending due to previous job failure')
                    WHERE jobID <> ?
                    AND userID = ?
                    AND moduleGroup = ?
                ",
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
}

=item _notifyRemoteServer

 Notify a remote node for a new job group to process

 Return boolean TRUE if the remote server has been notified, FALSE otherwise

=cut

sub _notifyRemoteNode
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
