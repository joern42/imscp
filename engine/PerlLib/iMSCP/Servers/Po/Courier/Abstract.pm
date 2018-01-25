=head1 NAME

 iMSCP::Servers::Po::Courier::Abstract - i-MSCP Courier IMAP/POP3 server abstract implementation

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

package iMSCP::Servers::Po::Courier::Abstract;

use strict;
use warnings;
use Array::Utils qw/ unique /;
use autouse Fcntl => qw/ O_RDONLY /;
use autouse 'iMSCP::Crypt' => qw/ ALNUM randomStr /;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isAvailableSqlUser isOneOfStringsInList isStringNotInList isValidPassword isValidUsername /;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Carp qw/ croak /;
use File::Spec;
use File::Temp;
use iMSCP::Config;
use iMSCP::Database;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute executeNoWait /;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Mount qw/ addMountEntry removeMountEntry isMountpoint mount umount /;
use iMSCP::ProgramFinder;
use iMSCP::Stepper qw/ endDetail startDetail step /;
use iMSCP::SystemUser;
use iMSCP::TemplateParser qw/ processByRef replaceBlocByRef /;
use iMSCP::Servers::Mta;
use iMSCP::Servers::Sqld;
use Sort::Naturally;
use Tie::File;
use parent 'iMSCP::Servers::Po';

%main::sqlUsers = () unless %main::sqlUsers;

=head1 DESCRIPTION

 i-MSCP Courier IMAP/POP3 server abstract implementation.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners()

 See iMSCP::Servers::Abstract::RegisterSetupListeners()

=cut

sub registerSetupListeners
{
    my ($self) = @_;

    my $rs = $self->SUPER::registerSetupListeners();
    $rs ||= $self->{'eventManager'}->registerOne(
        'beforeSetupDialog',
        sub {
            push @{$_[0]}, sub { $self->authdaemonSqlUserDialog( @_ ) };
            0;
        },
        $self->getPriority()
    );

    return $rs if $rs || index( $main::imscpConfig{'iMSCP::Servers::Mta'}, '::Postfix::' ) == -1;

    $self->{'eventManager'}->registerOne( 'beforePostfixConfigure', $self );
}

=item authdaemonSqlUserDialog(\%dialog)

 Authdaemon SQL user dialog

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub authdaemonSqlUserDialog
{
    my ($self, $dialog) = @_;

    my $masterSqlUser = main::setupGetQuestion( 'DATABASE_USER' );
    my $dbUser = main::setupGetQuestion(
        'PO_AUTHDAEMON_SQL_USER', $self->{'config'}->{'PO_AUTHDAEMON_DATABASE_USER'} || ( iMSCP::Getopt->preseed ? 'imscp_srv_user' : '' )
    );
    my $dbUserHost = main::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = main::setupGetQuestion(
        'PO_AUTHDAEMON_SQL_PASSWORD', ( iMSCP::Getopt->preseed ? randomStr( 16, ALNUM ) : $self->{'config'}->{'PO_AUTHDAEMON_DATABASE_PASSWORD'} )
    );

    $iMSCP::Dialog::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'po', 'servers', 'all', 'forced' ] )
        || !isValidUsername( $dbUser )
        || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' )
        || !isAvailableSqlUser( $dbUser )
    ) {
        my $rs = 0;

        do {
            if ( $dbUser eq '' ) {
                $iMSCP::Dialog::InputValidation::lastValidationError = '';
                $dbUser = 'imscp_srv_user';
            }

            ( $rs, $dbUser ) = $dialog->inputbox( <<"EOF", $dbUser );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a username for the Courier Authdaemon SQL user (leave empty for default):
\\Z \\Zn
EOF
        } while $rs < 30
            && ( !isValidUsername( $dbUser )
            || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' )
            || !isAvailableSqlUser( $dbUser )
        );

        return $rs unless $rs < 30;
    }

    main::setupSetQuestion( 'PO_AUTHDAEMON_SQL_USER', $dbUser );

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'po', 'servers', 'all', 'forced' ] ) || !isValidPassword( $dbPass ) ) {
        unless ( defined $main::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            my $rs = 0;

            do {
                if ( $dbPass eq '' ) {
                    $iMSCP::Dialog::InputValidation::lastValidationError = '';
                    $dbPass = randomStr( 16, ALNUM );
                }

                ( $rs, $dbPass ) = $dialog->inputbox( <<"EOF", $dbPass );
$iMSCP::Dialog::InputValidation::lastValidationError
Please enter a password for the Courier Authdaemon user (leave empty for autogeneration):
\\Z \\Zn
EOF
            } while $rs < 30 && !isValidPassword( $dbPass );

            return $rs unless $rs < 30;

            $main::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
        } else {
            $dbPass = $main::sqlUsers{$dbUser . '@' . $dbUserHost};
        }
    } elsif ( defined $main::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
        $dbPass = $main::sqlUsers{$dbUser . '@' . $dbUserHost};
    } else {
        $main::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
    }

    main::setupSetQuestion( 'PO_AUTHDAEMON_SQL_PASSWORD', $dbPass );
    0;
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ($self) = @_;

    my $rs = $self->_setVersion();
    $rs ||= $self->_configure();
    $rs ||= $self->_setupPostfixSasl() if index( $main::imscpConfig{'iMSCP::Servers::Mta'}, '::Postfix::' ) != -1;
    $rs ||= $self->_migrateFromDovecot();
}

=item uninstall( )

 See iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ($self) = @_;

    my $rs = $self->_dropSqlUser();
    $rs ||= $self->_removeConfig();
}

=item setEnginePermissions( )

 See iMSCP::Servers::Abstract::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    if ( -d $self->{'config'}->{'PO_AUTHLIB_SOCKET_DIR'} ) {
        my $rs ||= setRights( $self->{'config'}->{'PO_AUTHLIB_SOCKET_DIR'},
            {
                user  => $self->{'config'}->{'PO_AUTHDAEMON_USER'},
                group => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
                mode  => '0750'
            }
        );
        return $rs if $rs;
    }

    my $rs = setRights( "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/authmysqlrc",
        {
            user  => $self->{'config'}->{'PO_AUTHDAEMON_USER'},
            group => $self->{'config'}->{'PO_AUTHDAEMON_GROUP'},
            mode  => '0660'
        }
    );
    $rs ||= setRights( $self->{'config'}->{'QUOTA_WARN_MSG_PATH'},
        {
            user  => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0640'
        }
    );
    return $rs if $rs || !-f "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/dhparams.pem";

    setRights( "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/dhparams.pem",
        {
            user  => $self->{'config'}->{'PO_AUTHDAEMON_USER'},
            group => $self->{'config'}->{'PO_AUTHDAEMON_GROUP'},
            mode  => '0600'
        }
    );

}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ($self) = @_;

    'Courier';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'Courier %s', $self->getVersion());
}

=item getVersion( )

 See iMSCP::Servers::Abstract::getVersion()

=cut

sub getVersion
{
    my ($self) = @_;

    $self->{'config'}->{'PO_VERSION'};
}

=item addMail( \%moduleData )

 See iMSCP::Servers::Po::addMail()

=cut

sub addMail
{
    my ($self, $moduleData) = @_;

    return 0 unless index( $moduleData->{'MAIL_TYPE'}, '_mail' ) != -1;

    my $rs = $self->{'eventManager'}->trigger( 'beforeCourierAddMail', $moduleData );
    return $rs if $rs;

    my $mailDir = "$self->{'mta'}->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}";

    eval {
        for my $mailbox( '.Drafts', '.Junk', '.Sent', '.Trash' ) {
            iMSCP::Dir->new( dirname => "$mailDir/$mailbox" )->make( {
                user           => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'},
                group          => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
                mode           => 0750,
                fixpermissions => iMSCP::Getopt->fixPermissions
            } );

            for ( 'cur', 'new', 'tmp' ) {
                iMSCP::Dir->new( dirname => "$mailDir/$mailbox/$_" )->make( {
                    user           => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'},,
                    group          => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
                    mode           => 0750,
                    fixpermissions => iMSCP::Getopt->fixPermissions
                } );
            }
        }
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    my @subscribedFolders = ( 'INBOX.Drafts', 'INBOX.Junk', 'INBOX.Sent', 'INBOX.Trash' );
    my $subscriptionsFile = iMSCP::File->new( filename => "$mailDir/courierimapsubscribed" );

    if ( -f "$mailDir/courierimapsubscribed" ) {
        my $subscriptionsFileContent = $subscriptionsFile->get();
        unless ( defined $subscriptionsFile ) {
            error( "Couldn't read Courier subscriptions file" );
            return 1;
        }

        if ( $subscriptionsFileContent ne '' ) {
            @subscribedFolders = nsort unique ( @subscribedFolders, split( /\n/, $subscriptionsFileContent ));
        }
    }

    $rs = $subscriptionsFile->set( ( join "\n", @subscribedFolders ) . "\n" );
    $rs ||= $subscriptionsFile->save();
    $rs ||= $subscriptionsFile->owner( $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'}, $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'} );
    $rs ||= $subscriptionsFile->mode( 0640 );
    return $rs if $rs;

    if ( $moduleData->{'MAIL_QUOTA'} ) {
        if ( $self->{'quotaRecalc'}
            || ( iMSCP::Getopt->context() eq 'backend' && $moduleData->{'STATUS'} eq 'tochange' )
            || !-f "$mailDir/maildirsize"
        ) {
            $rs = execute( [ 'maildirmake', '-q', "$moduleData->{'MAIL_QUOTA'}S", $mailDir ], \ my $stdout, \ my $stderr );
            debug( $stdout ) if $stdout;
            error( $stderr || 'Unknown error' ) if $rs;
            return $rs if $rs;

            my $file = iMSCP::File->new( filename => "$mailDir/maildirsize" );
            $rs ||= $file->owner( $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'}, $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'} );
            $rs = $file->mode( 0640 );
            return $rs if $rs;
        }

        return 0;
    }

    if ( -f "$mailDir/maildirsize" ) {
        $rs = iMSCP::File->new( filename => "$mailDir/maildirsize" )->delFile();
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterCourierAddMail', $moduleData );
}

=item getTraffic( \%trafficDb [, $logFile, \%trafficIndexDb ] )

 See iMSCP::Servers::Po::getTraffic()

=cut

sub getTraffic
{
    my ($self, $trafficDb, $logFile, $trafficIndexDb) = @_;
    $logFile ||= "$main::imscpConfig{'TRAFF_LOG_DIR'}/$main::imscpConfig{'MAIL_TRAFF_LOG'}";

    unless ( -f $logFile ) {
        debug( sprintf( "IMAP/POP3 %s log file doesn't exist. Skipping...", $logFile ));
        return;
    }

    debug( sprintf( 'Processing IMAP/POP3 %s log file', $logFile ));

    # We use an index database to keep trace of the last processed logs
    $trafficIndexDb or tie %{$trafficIndexDb}, 'iMSCP::Config', fileName => "$main::imscpConfig{'IMSCP_HOMEDIR'}/traffic_index.db", nocroak => 1;
    my ($idx, $idxContent) = ( $trafficIndexDb->{'po_lineNo'} || 0, $trafficIndexDb->{'po_lineContent'} );

    tie my @logs, 'Tie::File', $logFile, mode => O_RDONLY, memory => 0 or croak( sprintf( "Couldn't tie %s file in read-only mode", $logFile ));

    # Retain index of the last log (log file can continue growing)
    my $lastLogIdx = $#logs;

    if ( exists $logs[$idx] && $logs[$idx] eq $idxContent ) {
        debug( sprintf( 'Skipping IMAP/POP3 logs that were already processed (lines %d to %d)', 1, ++$idx ));
    } elsif ( $idxContent ne '' && substr( $logFile, -2 ) ne '.1' ) {
        debug( 'Log rotation has been detected. Processing last rotated log file first' );
        $self->getTraffic( $trafficDb, $logFile . '.1', $trafficIndexDb );
        $idx = 0;
    }

    if ( $lastLogIdx < $idx ) {
        debug( 'No new IMAP/POP3 logs found for processing' );
        return;
    }

    debug( sprintf( 'Processing IMAP/POP3 logs (lines %d to %d)', $idx+1, $lastLogIdx+1 ));

    # Extract IMAP/POP3 traffic data
    #
    # Log line examples
    # Apr 21 15:14:44 www pop3d: LOGOUT, user=user@domain.tld, ip=[::ffff:192.168.1.1], port=[36852], top=0, retr=0, rcvd=6, sent=30, time=0, stls=1
    # Apr 21 15:14:55 www imapd: LOGOUT, user=user@domain.tld, ip=[::ffff:192.168.1.1], headers=0, body=0, rcvd=635, sent=1872, time=4477, starttls=1
    # Apr 21 15:23:12 www pop3d-ssl: LOGOUT, user=user@domain.tld, ip=[::ffff:192.168.1.1], port=[59556], top=0, retr=0, rcvd=12, sent=39, time=0, stls=1
    # Apr 21 15:24:36 www imapd-ssl: LOGOUT, user=user@domain.tld, ip=[::ffff:192.168.1.1], headers=0, body=0, rcvd=50, sent=374, time=10, starttls=1
    my $regexp = qr/(?:imapd|pop3d)(?:-ssl)?:.*user=[^\@]+\@(?<domain>[^,]+).*rcvd=(?<rcvd>\d+).*sent=(?<sent>\d+)/;

    # In term of memory usage, C-Style loop provide better results than using 
    # range operator in Perl-Style loop: for( @logs[$idx .. $lastLogIdx] ) ...
    for ( my $i = $idx; $i <= $lastLogIdx; $i++ ) {
        next unless $logs[$i] =~ /$regexp/ && exists $trafficDb->{$+{'domain'}};
        $trafficDb->{$+{'domain'}} += ( $+{'in'}+$+{'out'} );
    }

    return if substr( $logFile, -2 ) eq '.1';

    $trafficIndexDb->{'po_lineNo'} = $lastLogIdx;
    $trafficIndexDb->{'po_lineContent'} = $logs[$lastLogIdx];
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Servers::Po::_init()

=cut

sub _init
{
    my ($self) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    @{$self}{qw/ restart reload quotaRecalc mta cfgDir /} = ( 0, 0, 0, iMSCP::Servers::Mta->factory(), "$main::imscpConfig{'CONF_DIR'}/courier" );
    $self->SUPER::_init();
}

=item _setVersion( )

 Set Courier version

 Return int 0 on success, other on failure

=cut

sub _setVersion
{
    my ($self) = @_;

    croak ( sprintf( 'The %s class must implement the _setVersion() method', ref $self ));
}

=item _setupSqlUser( )

 Setup authdaemon SQL user

 Return int 0 on success, other on failure

=cut

sub _setupSqlUser
{
    my ($self) = @_;

    my $dbName = main::setupGetQuestion( 'DATABASE_NAME' );
    my $dbUser = main::setupGetQuestion( 'PO_AUTHDAEMON_SQL_USER' );
    my $dbUserHost = main::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = main::setupGetQuestion( 'PO_AUTHDAEMON_SQL_PASSWORD' );

    eval {
        my $sqlServer = iMSCP::Servers::Sqld->factory();

        # Drop old SQL user if required
        for my $sqlUser ( $self->{'config'}->{'PO_AUTHDAEMON_DATABASE_USER'}, $dbUser ) {
            next unless $sqlUser;

            for my $host( $dbUserHost, $main::imscpOldConfig{'DATABASE_USER_HOST'} ) {
                next if !$host || exists $main::sqlUsers{$sqlUser . '@' . $host} && !defined $main::sqlUsers{$sqlUser . '@' . $host};
                $sqlServer->dropUser( $sqlUser, $host );
            }
        }

        # Create SQL user if required
        if ( defined $main::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            debug( sprintf( 'Creating %s@%s SQL user', $dbUser, $dbUserHost ));
            $sqlServer->createUser( $dbUser, $dbUserHost, $dbPass );
            $main::sqlUsers{$dbUser . '@' . $dbUserHost} = undef;
        }

        my $dbh = iMSCP::Database->getInstance()->getRawDb();
        local $dbh->{'RaiseError'} = 1;

        # Give required privileges to this SQL user
        # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
        my $quotedDbName = $dbh->quote_identifier( $dbName );
        $dbh->do( "GRANT SELECT ON $quotedDbName.mail_users TO ?\@?", undef, $dbUser, $dbUserHost );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'config'}->{'PO_AUTHDAEMON_DATABASE_USER'} = $dbUser;
    $self->{'config'}->{'PO_AUTHDAEMON_DATABASE_PASSWORD'} = $dbPass;
    0;
}

=item _configure( )

 Configure Courier

 Return int 0 on success, other on failure

=cut

sub _configure
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeCourierConfigure' );
    $rs ||= $self->_setupSqlUser();
    $rs ||= $self->_buildDHparametersFile();
    $rs ||= $self->_buildAuthdaemonrcFile();
    $rs ||= $self->_buildSslConfFiles();
    $rs ||= $self->buildConfFile( 'authmysqlrc', "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/authmysqlrc", undef,
        {
            DATABASE_HOST        => main::setupGetQuestion( 'DATABASE_HOST' ),
            DATABASE_PORT        => main::setupGetQuestion( 'DATABASE_PORT' ),
            DATABASE_USER        => $self->{'config'}->{'PO_AUTHDAEMON_DATABASE_USER'},
            DATABASE_PASSWORD    => $self->{'config'}->{'PO_AUTHDAEMON_DATABASE_PASSWORD'},
            DATABASE_NAME        => main::setupGetQuestion( 'DATABASE_NAME' ),
            MTA_MAILBOX_UID      => ( scalar getpwnam( $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'} ) ),
            MTA_MAILBOX_GID      => ( scalar getgrnam( $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'} ) ),
            MTA_VIRTUAL_MAIL_DIR => $self->{'mta'}->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}
        },
        {
            umask => 0027,
            user  => $self->{'config'}->{'PO_AUTHDAEMON_USER'},
            group => $self->{'config'}->{'PO_AUTHDAEMON_GROUP'},
            mode  => 0640
        }
    );
    $rs ||= $self->buildConfFile( 'quota-warning', $self->{'config'}->{'QUOTA_WARN_MSG_PATH'}, undef,
        { HOSTNAME => main::setupGetQuestion( 'SERVER_HOSTNAME' ), },
        {
            umask => 0027,
            user  => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => 0640
        }
    );

    # Build local courier configuration files
    for my $sname( qw/ imapd imapd-ssl pop3d pop3d-ssl / ) {
        next unless -f "$self->{'cfgDir'}/$sname.local" && -f "$self->{'config'}->{'PO_CONF_DIR'}/$sname";

        my $file = iMSCP::File->new( filename => "$self->{'config'}->{'PO_CONF_DIR'}/$sname" );
        my $fileContentRef = $file->getAsRef();
        unless ( defined $fileContentRef ) {
            error( sprintf( "Couldn't read the %s file", $file->{'filename'} ));
            return 1;
        }

        replaceBlocByRef(
            qr/(?:^\n)?# iMSCP::Servers::Po::Courier::Abstract::installer - BEGIN\n/m,
            qr/# iMSCP::Servers::Po::Courier::Abstract::installer - ENDING\n/,
            '',
            $fileContentRef
        );

        ${$fileContentRef} .= <<"EOF";

# iMSCP::Servers::Po::Courier::Abstract::installer - BEGIN
. $self->{'cfgDir'}/$sname.local
# iMSCP::Servers::Po::Courier::Abstract::installer - ENDING
EOF
        $rs = $file->save();
        $rs ||= $file->owner( $main::imscpConfig{'ROOT_USER'}, $main::imscpConfig{'ROOT_GROUP'} );
        $rs ||= $file->mode( 0644 );
        return $rs if $rs;

        tie my %localConf, 'iMSCP::Config', fileName => "$self->{'cfgDir'}/$sname.local", nospaces => 1;

        if ( main::setupGetQuestion( 'IPV6_SUPPORT' ) ne 'yes' ) {
            if ( grep( $sname eq $_, 'imapd', 'pop3d' ) ) {
                $localConf{'ADDRESS'} = '0.0.0.0';
            } else {
                $localConf{'SSLADDRESS'} = '0.0.0.0';
            }
        } else {
            for ( qw/ ADDRESS SSLADDRESS / ) {
                next unless exists $localConf{$_} && $localConf{$_} eq '0.0.0.0';
                delete $localConf{$_};
            }
        }

        $self->{'eventManager'}->trigger( 'onCourierBuildLocalConf', $sname, \%localConf );
        untie( %localConf );
    }

    $self->{'eventManager'}->trigger( 'afterCourierConfigure' );
}

=item _setupPostfixSasl( )

 Setup SASL for Postfix

 Return int 0 on success, other on failure

=cut

sub _setupPostfixSasl
{
    my ($self) = @_;

    # Add postfix user in `mail' group to make it able to access
    # authdaemon rundir
    my $rs = iMSCP::SystemUser->new()->addToGroup( $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'}, $self->{'mta'}->{'config'}->{'MTA_USER'} );
    return $rs if $rs;

    # Mount authdaemond socket directory in Postfix chroot
    # Postfix won't be able to connect to socket located outside of its chroot
    my $fsSpec = File::Spec->canonpath( $self->{'config'}->{'PO_AUTHLIB_SOCKET_DIR'} );
    my $fsFile = File::Spec->canonpath( "$self->{'mta'}->{'config'}->{'MTA_QUEUE_DIR'}/$self->{'config'}->{'PO_AUTHLIB_SOCKET_DIR'}" );
    my $fields = { fs_spec => $fsSpec, fs_file => $fsFile, fs_vfstype => 'none', fs_mntops => 'bind,slave' };

    eval { iMSCP::Dir->new( dirname => $fsFile )->make(); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $rs = addMountEntry( "$fields->{'fs_spec'} $fields->{'fs_file'} $fields->{'fs_vfstype'} $fields->{'fs_mntops'}" );
    $rs ||= mount( $fields ) unless isMountpoint( $fields->{'fs_file'} );

    # Build Cyrus SASL smtpd.conf configuration file

    $rs ||= $self->{'eventManager'}->trigger( 'onLoadTemplate', 'courier', 'smtpd.conf', \ my $cfgTpl );
    return $rs if $rs;

    unless ( defined $cfgTpl ) {
        $cfgTpl = iMSCP::File->new( filename => "$self->{'cfgDir'}/sasl/smtpd.conf" )->get();
        unless ( defined $cfgTpl ) {
            error( sprintf( "Couldn't read the %s file", "$self->{'cfgDir'}/sasl/smtpd.conf" ));
            return 1;
        }
    }

    processByRef(
        {
            PWCHECK_METHOD     => $self->{'config'}->{'PWCHECK_METHOD'},
            LOG_LEVEL          => $self->{'config'}->{'LOG_LEVEL'},
            MECH_LIST          => $self->{'config'}->{'MECH_LIST'},
            PO_AUTHDAEMON_PATH => $self->{'config'}->{'PO_AUTHDAEMON_PATH'}
        },
        \$cfgTpl
    );

    my $file = iMSCP::File->new( filename => "$self->{'config'}->{'SASL_CONF_DIR'}/smtpd.conf" );
    $file->set( $cfgTpl );
    $rs = $file->save( 0027 );
    $rs ||= $file->owner( $main::imscpConfig{'ROOT_USER'}, $main::imscpConfig{'ROOT_GROUP'} );
    $rs ||= $file->mode( 0640 );
}

=item _buildDHparametersFile( )

 Build the DH parameters file with a stronger size (2048 instead of 768)

 Fix: #IP-1401
 Return int 0 on success, other on failure

=cut

sub _buildDHparametersFile
{
    my ($self) = @_;

    return 0 unless iMSCP::ProgramFinder::find( 'certtool' ) || iMSCP::ProgramFinder::find( 'mkdhparams' );

    if ( -f "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/dhparams.pem" ) {
        my $rs = execute(
            [ 'openssl', 'dhparam', '-in', "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/dhparams.pem", '-text', '-noout' ], \ my $stdout, \ my $stderr
        );
        debug( $stderr || 'Unknown error' ) if $rs;
        if ( $rs == 0 && $stdout =~ /\((\d+)\s+bit\)/ && $1 >= 2048 ) {
            return 0; # Don't regenerate file if not needed
        }

        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/dhparams.pem" )->delFile();
        return $rs if $rs;
    }

    startDetail();

    my $rs = step(
        sub {
            my ($tmpFile, $cmd);

            if ( iMSCP::ProgramFinder::find( 'certtool' ) ) {
                $tmpFile = File::Temp->new( UNLINK => 0 );
                $cmd = "certtool --generate-dh-params --sec-param medium > $tmpFile";
            } else {
                $cmd = 'DH_BITS=2048 mkdhparams';
            }

            my $output = '';
            my $outputHandler = sub {
                next if $_[0] =~ /^[.+]/;
                $output .= $_[0];
                step( undef, "Generating DH parameter file\n\n$output", 1, 1 );
            };

            my $rs = executeNoWait( $cmd, ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose ? sub {} : $outputHandler ), $outputHandler );
            error( $output || 'Unknown error' ) if $rs;
            $rs ||= iMSCP::File->new(
                filename => $tmpFile->filename )->moveFile( "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/dhparams.pem"
            ) if $tmpFile;
            $rs;
        }, 'Generating DH parameter file', 1, 1
    );
    endDetail();
    $rs;
}

=item _buildAuthdaemonrcFile( )

 Build the authdaemonrc file

 Return int 0 on success, other on failure

=cut

sub _buildAuthdaemonrcFile
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->registerOne(
        'beforeCourierBuildConfFile',
        sub {
            ${$_[0]} =~ s/authmodulelist=".*"/authmodulelist="authmysql"/;
            0;
        }
    );
    $rs ||= $self->buildConfFile( "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/authdaemonrc",
        "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/authdaemonrc", undef, undef,
        {
            umask => 0007,
            user  => $self->{'config'}->{'PO_AUTHDAEMON_USER'},
            group => $self->{'config'}->{'PO_AUTHDAEMON_GROUP'},
            mode  => 0660
        }
    );
}

=item _buildSslConfFiles( )

 Build ssl configuration file

 Return int 0 on success, other on failure

=cut

sub _buildSslConfFiles
{
    my ($self) = @_;

    return 0 unless main::setupGetQuestion( 'SERVICES_SSL_ENABLED', 'no' ) eq 'yes';

    for ( $self->{'config'}->{'PO_IMAP_SSL'}, $self->{'config'}->{'PO_POP_SSL'} ) {
        my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'courier', $_, \ my $cfgTpl, {} );
        return $rs if $rs;

        unless ( defined $cfgTpl ) {
            $cfgTpl = iMSCP::File->new( filename => "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/$_" )->get();
            unless ( defined $cfgTpl ) {
                error( sprintf( "Couldn't read the %s file", "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/$_" ));
                return 1;
            }
        }

        $rs = $self->{'eventManager'}->trigger( 'beforeCourierBuildSslConfFile', \ $cfgTpl, $_ );
        return $rs if $rs;

        if ( $cfgTpl =~ /^TLS_CERTFILE=/gm ) {
            $cfgTpl =~ s!^(TLS_CERTFILE=).*!$1$main::imscpConfig{'CONF_DIR'}/imscp_services.pem!gm;
        } else {
            $cfgTpl .= "TLS_CERTFILE=$main::imscpConfig{'CONF_DIR'}/imscp_services.pem\n";
        }

        $rs = $self->{'eventManager'}->trigger( 'afterCourierBuildSslConfFile', \ $cfgTpl, $_ );
        return $rs if $rs;

        my $file = iMSCP::File->new( filename => "$self->{'config'}->{'PO_AUTHLIB_CONF_DIR'}/$_" );
        $file->set( $cfgTpl );
        $rs = $file->save();
        $rs ||= $file->owner( $main::imscpConfig{'ROOT_USER'}, $main::imscpConfig{'ROOT_GROUP'} );
        $rs ||= $file->mode( 0644 );
        return $rs if $rs;
    }

    0;
}

=item _migrateFromDovecot( )

 Migrate mailboxes from Dovecot

 Return int 0 on success, other on failure

=cut

sub _migrateFromDovecot
{
    my ($self) = @_;

    return 0 unless index( $main::imscpOldConfig{'iMSCP::Servers::Po'}, '::Dovecot::' ) != -1;

    my $rs = execute(
        [
            '/usr/bin/perl', "$main::imscpConfig{'ENGINE_ROOT_DIR'}/PerlVendor/courier-dovecot-migrate.pl", '--to-courier', '--quiet', '--convert',
            '--overwrite', '--recursive', $self->{'mta'}->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}
        ],
        \ my $stdout,
        \ my $stderr
    );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;

    unless ( $rs ) {
        $self->{'quotaRecalc'} = 1;
        $main::imscpOldConfig{'iMSCP::Servers::Po'} = $main::imscpConfig{'iMSCP::Servers::Po'};
    }

    $rs;
}

=item _dropSqlUser( )

 Drop SQL user

 Return int 0 on success, other on failure

=cut

sub _dropSqlUser
{
    my ($self) = @_;

    # In setup context, take value from old conffile, else take value from current conffile
    my $dbUserHost = iMSCP::Getopt->context() eq 'installer'
        ? $main::imscpOldConfig{'DATABASE_USER_HOST'} : $main::imscpConfig{'DATABASE_USER_HOST'};

    return 0 unless $self->{'config'}->{'PO_AUTHDAEMON_DATABASE_USER'} && $dbUserHost;

    eval { iMSCP::Servers::Sqld->factory()->dropUser( $self->{'config'}->{'PO_AUTHDAEMON_DATABASE_USER'}, $dbUserHost ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _removeConfig( )

 Remove configuration

 Return int 0 on success, other on failure

=cut

sub _removeConfig
{
    my ($self) = @_;

    # Umount the courier-authdaemond rundir from the Postfix chroot
    my $fsFile = File::Spec->canonpath( "$self->{'mta'}->{'config'}->{'MTA_QUEUE_DIR'}/$self->{'config'}->{'PO_AUTHLIB_SOCKET_DIR'}" );
    my $rs = removeMountEntry( qr%.*?[ \t]+\Q$fsFile\E(?:/|[ \t]+)[^\n]+% );
    $rs ||= umount( $fsFile );
    return $rs if $rs;

    eval { iMSCP::Dir->new( dirname => $fsFile )->remove(); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    # Remove the `postfix' user from the `mail' group
    $rs = iMSCP::SystemUser->new()->removeFromGroup( $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'}, $self->{'mta'}->{'config'}->{'MTA_USER'} );
    return $rs if $rs;

    # Remove i-MSCP configuration stanza from the courier-imap daemon configuration file
    if ( -f "$self->{'config'}->{'PO_CONF_DIR'}/imapd" ) {
        my $file = iMSCP::File->new( filename => "$self->{'config'}->{'PO_CONF_DIR'}/imapd" );
        my $fileContentRef = $file->getAsRef();
        unless ( defined $fileContentRef ) {
            error( sprintf( "Couldn't read the %s file", $file->{'filename'} ));
            return 1;
        }

        replaceBlocByRef(
            qr/(?:^\n)?# iMSCP::Servers::Po::Courier::Abstract::installer - BEGIN\n/m,
            qr/# iMSCP::Servers::Po::Courier::Abstract::installer - ENDING\n/,
            '',
            $fileContentRef
        );

        $rs = $file->save();
        $rs ||= $file->owner( $main::imscpConfig{'ROOT_USER'}, $main::imscpConfig{'ROOT_GROUP'} );
        $rs ||= $file->mode( 0644 );
        return $rs if $rs;
    }

    # Remove the configuration file for SASL
    if ( -f "$self->{'config'}->{'SASL_CONF_DIR'}/smtpd.conf" ) {
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'SASL_CONF_DIR'}/smtpd.conf" )->delFile();
        return $rs if $rs;
    }

    # Remove the systemd-tmpfiles file
    if ( -f '/etc/tmpfiles.d/courier-authdaemon.conf' ) {
        $rs = iMSCP::File->new( filename => '/etc/tmpfiles.d/courier-authdaemon.conf' )->delFile();
        return $rs if $rs;
    }

    # Remove the quota warning script
    if ( -f $self->{'config'}->{'QUOTA_WARN_MSG_PATH'} ) {
        $rs = iMSCP::File->new( filename => $self->{'config'}->{'QUOTA_WARN_MSG_PATH'} )->delFile();
        return $rs if $rs;
    }

    0;
}

=back

=head1 EVENT LISTENERS

=over 4

=item beforePostfixConfigure( $courierServer )

 Injects configuration for both, maildrop MDA and Cyrus SASL in Postfix configuration files.

 Param iMSCP::Servers::Courier::Abstract $courierServer Courier server instance
 Return int 0 on success, other on failure

=cut

sub beforePostfixConfigure
{
    my ($courierServer) = @_;

    my $rs = $courierServer->{'eventManager'}->register(
        'afterPostfixBuildFile',
        sub {
            my ($cfgTpl, $cfgTplName) = @_;

            return 0 unless $cfgTplName eq 'master.cf';
            ${$cfgTpl} .= <<"EOF";
maildrop  unix  -       n       n       -       -       pipe
 flags=DRhu user=$courierServer->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'}:$courierServer->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'} argv=maildrop -w 90 -d \${user}\@\${nexthop} \${extension} \${recipient} \${user} \${nexthop} \${sender}
EOF
            0;
        }
    );
    $rs ||= $courierServer->{'eventManager'}->registerOne(
        'afterPostfixConfigure',
        sub {
            $courierServer->{'mta'}->postconf( (
                # Maildrop MDA parameters
                virtual_transport                      => {
                    action => 'replace',
                    values => [ 'maildrop' ]
                },
                maildrop_destination_concurrency_limit => {
                    action => 'replace',
                    values => [ '2' ]
                },
                maildrop_destination_recipient_limit   => {
                    action => 'replace',
                    values => [ '1' ]
                },
                # Cyrus SASL parameters
                smtpd_sasl_type                        => {
                    action => 'replace',
                    values => [ 'cyrus' ]
                },
                smtpd_sasl_path                        => {
                    action => 'replace',
                    values => [ 'smtpd' ]
                },
                smtpd_sasl_auth_enable                 => {
                    action => 'replace',
                    values => [ 'yes' ]
                },
                smtpd_sasl_security_options            => {
                    action => 'replace',
                    values => [ 'noanonymous' ]
                },
                smtpd_sasl_authenticated_header        => {
                    action => 'replace',
                    values => [ 'yes' ]
                },
                broken_sasl_auth_clients               => {
                    action => 'replace',
                    values => [ 'yes' ]
                },
                # SMTP restrictions
                smtpd_helo_restrictions                => {
                    action => 'add',
                    values => [ 'permit_sasl_authenticated' ],
                    after  => qr/permit_mynetworks/
                },
                smtpd_sender_restrictions              => {
                    action => 'add',
                    values => [ 'permit_sasl_authenticated' ],
                    after  => qr/permit_mynetworks/
                },
                smtpd_recipient_restrictions           => {
                    action => 'add',
                    values => [ 'permit_sasl_authenticated' ],
                    after  => qr/permit_mynetworks/
                }
            ));
        }
    );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
