#!/usr/bin/perl

=head1 NAME

 imscp-backup-imscp backup i-MSCP configuration files and database.

=head1 SYNOPSIS

 imscp-backup-imscp [options]...

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by internet Multi Server Control Panel
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

use strict;
use warnings;
use File::Basename;
use File::Spec;
use FindBin;
use lib "$FindBin::Bin/../../../../../../PerlLib", "$FindBin::Bin/../../../../../../PerlVendor";
use iMSCP::Boolean;
use iMSCP::Bootstrapper;
use iMSCP::Debug qw/ debug error getMessageByType newDebug /;
use iMSCP::Execute 'execute';
use iMSCP::File;
use iMSCP::Dir;
use iMSCP::Getopt;
use iMSCP::Mail;
use iMSCP::Package::Installer::Backup;
use POSIX qw/ strftime locale_h /;

our $CMDS = {
    pbzip2 => {
        extension => 'bz2',
        command   => 'pbzip2'
    },
    bzip2  => {
        extension => 'bz2',
        command   => 'bzip2'
    },
    gzip   => {
        extension => 'gz',
        command   => 'gzip'
    },
    pigz   => {
        extension => 'gz',
        command   => 'pigz'
    },
    lzma   => {
        extension => 'lzma',
        command   => 'lzma'
    },
    xz     => {
        extension => 'xz',
        command   => 'xz'
    }
};

sub backupDatabase
{
    my $db = iMSCP::Database->factory();

    eval { $db->dumpdb( $::imscpConfig{'DATABASE_NAME'}, "$::imscpConfig{'ROOT_DIR'}/backups" ) };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    # Encode slashes as SOLIDUS unicode character
    # Encode dots as Full stop unicode character
    ( my $encodedDbName = $::imscpConfig{'DATABASE_NAME'} ) =~ s%([./])%{ '/', '@002f', '.', '@002e' }->{$1}%ge;
    my $date = strftime "%Y.%m.%d-%H-%M", localtime;

    my $rs = iMSCP::File->new( filename => "$::imscpConfig{'ROOT_DIR'}/backups/$encodedDbName.sql" )->moveFile(
        "$::imscpConfig{'ROOT_DIR'}/backups/$encodedDbName-$date.sql"
    );
    return $rs if $rs;

    my $bkp = iMSCP::Package::Installer::Backup->getInstance();
    if ( $bkp->{'config'}->{'BACKUP_COMPRESS_ALGORITHM'} ne 'no' ) {
        $rs = execute(
            [
                $CMDS->{$bkp->{'config'}->{'BACKUP_COMPRESS_ALGORITHM'}}->{'command'},
                "-$bkp->{'config'}->{'BACKUP_COMPRESS_LEVEL'}",
                '--force',
                "$::imscpConfig{'ROOT_DIR'}/backups/$encodedDbName-$date.sql"
            ]
            ,
            \my $stdout,
            \my $stderr
        );
        debug( $stdout ) if $stdout;

        if ( $rs > 1 ) {
            # Tar exit with status 1 only if some files were changed while being read. We want ignore this.
            error( $stderr || 'Unknown error' );
            return $rs if $rs;
        }
    }

    0;
}

sub backupConfig
{
    my $date = strftime "%Y.%m.%d-%H-%M", localtime;
    my $archPath = "$::imscpConfig{'ROOT_DIR'}/backups/config-backup-$date.tar";
    my $bkp = iMSCP::Package::Installer::Backup->getInstance();

    if ( $bkp->{'config'}->{'BACKUP_COMPRESS_ALGORITHM'} ne 'none' ) {
        $archPath .= '.' . $bkp->{$::imscpConfig{'BACKUP_COMPRESS_ALGORITHM'}}->{'extension'};
    }

    my @cmd = (
        "tar -c -C $::imscpConfig{'CONF_DIR'}",
        '--exclude=./*/backup/*.[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',
        '--preserve-permissions',
        '.',
        ( $bkp->{'config'}->{'BACKUP_COMPRESS_ALGORITHM'} eq 'none'
            ? "-f $archPath"
            : " | $CMDS->{$bkp->{'config'}->{'BACKUP_COMPRESS_ALGORITHM'}}->{'command'} -$bkp->{'config'}->{'BACKUP_COMPRESS_LEVEL'} > $archPath"
        )
    );

    my $rs = execute( "@cmd", \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    0;
}

setlocale( LC_MESSAGES, "C.UTF-8" );

$ENV{'LANG'} = 'C.UTF-8';

newDebug( 'imscp-backup-imscp.log' );

iMSCP::Getopt->parse( sprintf( "Usage: perl %s [OPTION]...", basename( $0 )) . qq{

Script which backup i-MSCP configuration files and database.

OPTIONS:
 -v,    --verbose       Enable verbose mode.},
    'debug|d'   => \&iMSCP::Getopt::debug,
    'verbose|v' => \&iMSCP::Getopt::verbose
);

my $bootstrapper = iMSCP::Bootstrapper->getInstance();
exit unless $bootstrapper->lock( '/var/lock/imscp-backup-imscp.lock', 'nowait' );

$bootstrapper->boot( {
    config_readonly => TRUE,
    nolock          => TRUE
} );

# Make sure that backup directory exists
iMSCP::Dir->new( dirname => "$::imscpConfig{'ROOT_DIR'}/backups" )->make( {
    user  => $::imscpConfig{'ROOT_USER'},
    group => $::imscpConfig{'ROOT_GROUP'},
    mode  => 0750
} );

my $rs = backupConfig();
$rs ||= backupDatabase();

if ( $rs && ( my @errorMessages = getMessageByType( 'error' ) ) ) {
    iMSCP::Mail->new()->errmsg( "@errorMessages" );
}

exit $rs;

=head1 AUTHOR

 i-MSCP Team <team@i-mscp.net>

=cut
