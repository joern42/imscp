#!/usr/bin/perl

package JobQueueManager;

use strict;
use warnings;
use Parallel::ForkManager;
use IPC::Shareable ();

my @jobGroups = (
    [ 'job group 1' => 1 ],
    [ 'job group 2' => 1 ],
    [ 'job group 3' => 1 ],
    [ 'job group 4' => 1 ],
    [ 'job group 5' => 1 ]
);


sub new
{
    my ($class) = @_;

    
    my $self = bless {}, $class;
    tie $self->{'shared'}, 'IPC::Shareable';
    $self;
}

sub processJobs
{
    my ($self) = @_;
    
    my $pm = Parallel::ForkManager->new( 100 );
    $pm->set_waitpid_blocking_sleep( 1 ); # true blocking calls enabled
    JOB_GROUP:
    for my $jobGroup ( @jobGroups ) {
        next JOB_GROUP if $pm->start();

        #sleep( $jobGroup->[1] );

        print "Processing $jobGroup->[0] (PID $$)\n";
        
        if ( $self->{'shared'} ) {
            print "shared variable has been initialized with value: $self->{'shared'}\n";
        } else {
            print "shared variable has not been initialized yet\n";
            $self->{'shared'} = "good";
        }

        $pm->finish();
    }

    $pm->wait_all_children;
}

package main;

my $manager = JobQueueManager->new();
$manager->processJobs();
