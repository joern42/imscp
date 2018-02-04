=head1 NAME

 iMSCP::Servers::Po::Dovecot::Abstract - i-MSCP Dovecot IMAP/POP3 Server implementation

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

package iMSCP::Servers::Po::Dovecot::Abstract;

use strict;
use warnings;
use Array::Utils qw/ unique /;
use autouse Fcntl => qw/ O_RDONLY /;
use autouse 'iMSCP::Crypt' => qw/ ALNUM randomStr /;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isAvailableSqlUser isOneOfStringsInList isStringNotInList isValidPassword isValidUsername /;
use autouse 'iMSCP::Execute' => qw/ execute /;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Database /;
use iMSCP::Config;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Servers::Mta;
use iMSCP::Servers::Sqld;
use Sort::Naturally;
use Tie::File;
use parent 'iMSCP::Servers::Po';

%main::sqlUsers = () unless %main::sqlUsers;

=head1 DESCRIPTION

 i-MSCP Dovecot IMAP/POP3 Server implementation.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 See iMSCP::Servers::Abstract::RegisterSetupListeners()

=cut

sub registerSetupListeners
{
    my ($self) = @_;

    $self->{'eventManager'}->registerOne( 'beforeSetupDialog', sub { push @{$_[0]}, sub { $self->showSqlUserDialog( @_ ) }; }, $self->getPriority());

    return if index( $main::imscpConfig{'iMSCP::Servers::Mta'}, '::Postfix::' ) == -1;

    $self->{'eventManager'}->registerOne( 'beforePostfixConfigure', $self );
}

=item showSqlUserDialog( \%dialog )

 Ask user for Dovecot restricted SQL user

 Param iMSCP::Dialog \%dialog
 Return int 0 on success, other on failure

=cut

sub showSqlUserDialog
{
    my ($self, $dialog) = @_;

    my $masterSqlUser = main::setupGetQuestion( 'DATABASE_USER' );
    my $dbUser = main::setupGetQuestion( 'PO_SQL_USER', $self->{'config'}->{'PO_SQL_USER'} || ( iMSCP::Getopt->preseed ? 'imscp_srv_user' : '' ));
    my $dbUserHost = main::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = main::setupGetQuestion(
        'PO_SQL_PASSWORD', ( iMSCP::Getopt->preseed ? randomStr( 16, ALNUM ) : $self->{'config'}->{'PO_SQL_PASSWORD'} )
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
Please enter a username for the Dovecot SQL user (leave empty for default):
\\Z \\Zn
EOF
        } while $rs < 30 && ( !isValidUsername( $dbUser )
            || !isStringNotInList( lc $dbUser, 'root', 'debian-sys-maint', lc $masterSqlUser, 'vlogger_user' ) || !isAvailableSqlUser( $dbUser )
        );

        return $rs unless $rs < 30;
    }

    main::setupSetQuestion( 'PO_SQL_USER', $dbUser );

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
Please enter a password for the Dovecot SQL user (leave empty for autogeneration):
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

    main::setupSetQuestion( 'PO_SQL_PASSWORD', $dbPass );
    0;
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ($self) = @_;

    $self->_setVersion();
    $self->_configure();
    $self->_migrateFromCourier();
}

=item uninstall( )

 See iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ($self) = @_;

    $self->_dropSqlUser();
    $self->_removeConfig();
}

=item setEnginePermissions( )

 See iMSCP::Servers::Abstract::setEnginePermissions()

=cut

sub setEnginePermissions
{
    my ($self) = @_;

    setRights( $self->{'config'}->{'PO_CONF_DIR'},
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0755'
        }
    );
    setRights( "$self->{'config'}->{'PO_CONF_DIR'}/dovecot.conf",
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
            mode  => '0640'
        }
    );
    setRights( "$self->{'config'}->{'PO_CONF_DIR'}/dovecot-sql.conf",
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
            mode  => '0640'
        }
    );
    setRights( "$main::imscpConfig{'ENGINE_ROOT_DIR'}/quota/imscp-dovecot-quota.sh",
        {
            user  => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'},
            group => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
            mode  => '0750'
        }
    );
}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ($self) = @_;

    'Dovecot';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'Dovecot %s', $self->getVersion());
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

 Process addMail tasks

 Param hashref \%moduleData Mail data
 Return int 0 on success, other or die on failure

=cut

sub addMail
{
    my ($self, $moduleData) = @_;

    return unless index( $moduleData->{'MAIL_TYPE'}, '_mail' ) != -1;

    $self->{'eventManager'}->trigger( 'beforeDovecotAddMail', $moduleData );

    my $mailDir = "$self->{'mta'}->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}";

    for my $mailbox( '.Drafts', '.Junk', '.Sent', '.Trash' ) {
        iMSCP::Dir->new( dirname => "$mailDir/$mailbox" )->make( {
            user           => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'},
            group          => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
            mode           => 0750,
            fixpermissions => iMSCP::Getopt->fixPermissions
        } );

        for ( 'cur', 'new', 'tmp' ) {
            iMSCP::Dir->new( dirname => "$mailDir/$mailbox/$_" )->make( {
                user           => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'},
                group          => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
                mode           => 0750,
                fixpermissions => iMSCP::Getopt->fixPermissions
            } );
        }
    }

    my @subscribedFolders = ( 'Drafts', 'Junk', 'Sent', 'Trash' );
    my $subscriptionsFile = iMSCP::File->new( filename => "$mailDir/subscriptions" );

    if ( -f subscriptionsFile ) {
        my $subscriptionsFileContent = $subscriptionsFile->get();
        @subscribedFolders = nsort unique ( @subscribedFolders, split( /\n/, $subscriptionsFileContent )) if $subscriptionsFileContent ne '';
    }

    $subscriptionsFile
        ->set( ( join "\n", @subscribedFolders ) . "\n" )
        ->save()
        ->owner( $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'}, $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'} )
        ->mode( 0640 );

    if ( $moduleData->{'MAIL_QUOTA'} ) {
        if ( $self->{'quotaRecalc'}
            || ( iMSCP::Getopt->context() eq 'backend' && $moduleData->{'STATUS'} eq 'tochange' )
            || !-f "$mailDir/maildirsize"
        ) {
            # TODO create maildirsize file manually (set quota definition and recalculate byte and file counts)
            iMSCP::File->new( filename => "$mailDir/maildirsize" )->remove();
        }

        return 0;
    }

    iMSCP::File->new( filename => "$mailDir/maildirsize" )->remove();

    $self->{'eventManager'}->trigger( 'afterDovecotAddMail', $moduleData );
}

=item getTraffic( \%trafficDb [, $logFile, \%trafficIndexDb ] )

 Get IMAP/POP3 traffic data

 Param hashref \%trafficDb Traffic database
 Param string $logFile Path to SMTP log file (only when self-called)
 Param hashref \%trafficIndexDb Traffic index database (only when self-called)
 Return void, croak on failure

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

    tie my @logs, 'Tie::File', $logFile, mode => O_RDONLY, memory => 0 or die( sprintf( "Couldn't tie %s file in read-only mode", $logFile ));

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
    # Apr 18 23:41:48 jessie dovecot: imap(user@domain.tld): Disconnected: Logged out in=244 out=858
    # Apr 18 23:41:48 jessie dovecot: pop3(user@domain.tld): Disconnected: Logged out top=0/0, retr=0/0, del=0/0, size=0, in=12, out=43
    my $regexp = qr/(?:imap|pop3)\([^\@]+\@(?<domain>[^\)]+)\):.*in=(?<in>\d+).*out=(?<out>\d+)$/;

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

    @{$self}{qw/ restart reload quotaRecalc mta cfgDir /} = ( 0, 0, 0, iMSCP::Servers::Mta->factory(), "$main::imscpConfig{'CONF_DIR'}/dovecot" );
    $self->SUPER::_init();
}

=item _setVersion( )

 Set Dovecot version

 Return void, die on failure

=cut

sub _setVersion
{
    my ($self) = @_;

    my $rs = execute( [ $self->{'config'}->{'PO_BIN'}, '--version' ], \ my $stdout, \ my $stderr );
    !$rs or die( $stderr || 'Unknown error' );
    $stdout =~ m/^([\d.]+)/ or die( "Couldn't guess Dovecot version from the `$self->{'config'}->{'PO_BIN'}--version` command output" );
    $self->{'config'}->{'PO_VERSION'} = $1;
    debug( sprintf( 'Dovecot version set to: %s', $1 ));
}

=item _configure( )

 Configure Dovecot

 Return void, die on failure

=cut

sub _configure
{
    my ($self) = @_;

    $self->{'eventManager'}->trigger( 'beforeDovecotConfigure' );
    $self->_setupSqlUser();

    # Make the imscp.d directory free of any file that were
    # installed by i-MSCP listener files.
    iMSCP::Dir->new( dirname => "$self->{'config'}->{'PO_CONF_DIR'}/imscp.d" )->clear( qr/_listener\.conf$/ );

    $self->{'eventManager'}->registerOne(
        'beforeDovecotBuildConfFile',
        sub {
            ${$_[0]} .= <<"EOF";

# SSL

ssl = @{[ main::setupGetQuestion( 'SERVICES_SSL_ENABLED' ) ]}
EOF
            # FIXME Find a better way to guess libssl version (dovecot --build-options ???)
            if ( main::setupGetQuestion( 'SERVICES_SSL_ENABLED' ) eq 'yes' ) {
                unless ( `ldd /usr/lib/dovecot/libdovecot-login.so | grep libssl.so` =~ /libssl.so.(\d.\d)/ ) {
                    error( "Couldn't guess libssl version against which Dovecot has been built" );
                    return 1;
                }

                ${$_[0]} .= <<"EOF";
ssl_protocols = @{[ version->parse( $1 ) >= version->parse( '1.1' ) ? '!SSLv3' : '!SSLv2 !SSLv3' ]}
ssl_cert = <$main::imscpConfig{'CONF_DIR'}/imscp_services.pem
ssl_key = <$main::imscpConfig{'CONF_DIR'}/imscp_services.pem
EOF
            }
        }
    );
    $self->buildConfFile( 'dovecot.conf', "$self->{'config'}->{'PO_CONF_DIR'}/dovecot.conf", undef,
        {
            PO_CONF_DIR              => $self->{'config'}->{'PO_CONF_DIR'},
            PO_SASL_AUTH_SOCKET_PATH => $self->{'config'}->{'PO_SASL_AUTH_SOCKET_PATH'},
            PO_LISTEN_INTERFACES     => main::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ? '*, [::]' : '*',
            ENGINE_ROOT_DIR          => $main::imscpConfig{'ENGINE_ROOT_DIR'},
            IMSCP_GROUP              => $main::imscpConfig{'IMSCP_GROUP'},
            MTA_MAILBOX_UID_NAME     => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'},
            MTA_USER                 => $self->{'mta'}->{'config'}->{'MTA_USER'},
            MTA_GROUP                => $self->{'mta'}->{'config'}->{'MTA_GROUP'},
            SERVER_HOSTNAME          => main::setupGetQuestion( 'SERVER_HOSTNAME' ),
        },
        {
            umask => 0027,
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
            mode  => 0640
        }
    );
    $self->buildConfFile( 'dovecot-sql.conf', "$self->{'config'}->{'PO_CONF_DIR'}/dovecot-sql.conf", undef,
        {
            PO_DATABASE_HOST     => main::setupGetQuestion( 'DATABASE_HOST' ),
            PO_DATABASE_NAME     => main::setupGetQuestion( 'DATABASE_NAME' ) =~ s%('|"|\\)%\\$1%gr,
            PO_DATABASE_PORT     => main::setupGetQuestion( 'DATABASE_PORT' ),
            PO_SQL_USER          => $self->{'config'}->{'PO_SQL_USER'} =~ s%('|"|\\)%\\$1%gr,
            PO_SQL_PASSWORD      => $self->{'config'}->{'PO_SQL_PASSWORD'} =~ s%('|"|\\)%\\$1%gr,
            MTA_MAILBOX_GID      => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
            MTA_MAILBOX_UID      => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'},
            MTA_VIRTUAL_MAIL_DIR => $self->{'mta'}->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}
        },
        {
            umask => 0027,
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
            mode  => 0640
        }
    );
    $self->buildConfFile( 'quota-warning', "$main::imscpConfig{'ENGINE_ROOT_DIR'}/quota/imscp-dovecot-quota.sh", undef,
        {
            PO_DELIVER_PATH => $self->{'config'}->{'PO_DELIVER_PATH'},
            HOSTNAME        => main::setupGetQuestion( 'SERVER_HOSTNAME' )
        },
        {
            umask => 0027,
            user  => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'},
            group => $self->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'},
            mode  => 0750
        }
    );
    $self->{'eventManager'}->trigger( 'afterDovecotConfigure' );
}

=item _setupSqlUser( )

 Setup SQL user

 Return void, die on failure

=cut

sub _setupSqlUser
{
    my ($self) = @_;

    my $dbName = main::setupGetQuestion( 'DATABASE_NAME' );
    my $dbUser = main::setupGetQuestion( 'PO_SQL_USER' );
    my $dbUserHost = main::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = main::setupGetQuestion( 'PO_SQL_PASSWORD' );
    my $sqlServer = iMSCP::Servers::Sqld->factory();

    # Drop old SQL user if required
    for my $sqlUser ( $self->{'config'}->{'PO_SQL_USER'}, $dbUser ) {
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

    my $dbh = iMSCP::Database->getInstance();

    # Give required privileges to this SQL user
    # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
    my $quotedDbName = $dbh->quote_identifier( $dbName );
    $dbh->do( "GRANT SELECT ON $quotedDbName.mail_users TO ?\@?", undef, $dbUser, $dbUserHost );

    $self->{'config'}->{'PO_SQL_USER'} = $dbUser;
    $self->{'config'}->{'PO_SQL_PASSWORD'} = $dbPass;
}

=item _migrateFromCourier( )

 Migrate mailboxes from Courier

 Return void, die on failure

=cut

sub _migrateFromCourier
{
    my ($self) = @_;

    return unless index( $main::imscpOldConfig{'iMSCP::Servers::Po'}, '::Courier::' ) != -1;

    my $rs = execute(
        [
            'perl', "$main::imscpConfig{'ENGINE_ROOT_DIR'}/PerlVendor/courier-dovecot-migrate.pl", '--to-dovecot', '--quiet', '--convert',
            '--overwrite', '--recursive', $self->{'mta'}->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}
        ],
        \ my $stdout,
        \ my $stderr
    );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );

    $self->{'quotaRecalc'} = 1;
    $main::imscpOldConfig{'iMSCP::Servers::Po'} = $main::imscpConfig{'iMSCP::Servers::Po'};
}

=item _dropSqlUser( )

 Drop SQL user

 Return void, die on failure

=cut

sub _dropSqlUser
{
    my ($self) = @_;

    # In setup context, take value from old conffile, else take value from current conffile
    my $dbUserHost = iMSCP::Getopt->context() eq 'installer'
        ? $main::imscpOldConfig{'DATABASE_USER_HOST'} : $main::imscpConfig{'DATABASE_USER_HOST'};

    return unless $self->{'config'}->{'PO_SQL_USER'} && $dbUserHost;

    iMSCP::Servers::Sqld->factory()->dropUser( $self->{'config'}->{'PO_SQL_USER'}, $dbUserHost );
}

=item _removeConfig( )

 Remove configuration

 Return void, die on failure

=cut

sub _removeConfig
{
    my ($self) = @_;

    iMSCP::Dir->new( dirnname => "$self->{'config'}->{'PO_CONF_DIR'}/imscp.d" )->remove();
}

=back

=head1 EVENT LISTENERS

=over 4

=item beforePostfixConfigure( $dovecotServer )

 Injects configuration for both, Dovecot LDA and Dovecot SASL in Postfix configuration files.

 Param iMSCP::Servers::Dovecot::Abstract $dovecotServer Dovecot Server instance
 Return void, die on failure

=cut

sub beforePostfixConfigure
{
    my ($dovecotServer) = @_;

    $dovecotServer->{'eventManager'}->register(
        'afterPostfixBuildFile',
        sub {
            my ($cfgTpl, $cfgTplName) = @_;

            return unless $cfgTplName eq 'master.cf';
            ${$cfgTpl} .= <<"EOF";
dovecot   unix  -       n       n       -       -       pipe
 flags=DRhu user=$dovecotServer->{'mta'}->{'config'}->{'MTA_MAILBOX_UID_NAME'}:$dovecotServer->{'mta'}->{'config'}->{'MTA_MAILBOX_GID_NAME'} argv=$dovecotServer->{'config'}->{'PO_DELIVER_PATH'} -f \${sender} -d \${user}\@\${nexthop} -m INBOX.\${extension}
EOF
        }
    );
    $dovecotServer->{'eventManager'}->registerOne(
        'afterPostfixConfigure',
        sub {
            $dovecotServer->{'mta'}->postconf( (
                # Dovecot LDA parameters
                virtual_transport                     => {
                    action => 'replace',
                    values => [ 'dovecot' ]
                },
                dovecot_destination_concurrency_limit => {
                    action => 'replace',
                    values => [ '2' ]
                },
                dovecot_destination_recipient_limit   => {
                    action => 'replace',
                    values => [ '1' ]
                },
                # Dovecot SASL parameters
                smtpd_sasl_type                       => {
                    action => 'replace',
                    values => [ 'dovecot' ]
                },
                smtpd_sasl_path                       => {
                    action => 'replace',
                    values => [ 'private/auth' ]
                },
                smtpd_sasl_auth_enable                => {
                    action => 'replace',
                    values => [ 'yes' ]
                },
                smtpd_sasl_security_options           => {
                    action => 'replace',
                    values => [ 'noanonymous' ]
                },
                smtpd_sasl_authenticated_header       => {
                    action => 'replace',
                    values => [ 'yes' ]
                },
                broken_sasl_auth_clients              => {
                    action => 'replace',
                    values => [ 'yes' ]
                },
                # SMTP restrictions
                smtpd_helo_restrictions               => {
                    action => 'add',
                    values => [ 'permit_sasl_authenticated' ],
                    after  => qr/permit_mynetworks/
                },
                smtpd_sender_restrictions             => {
                    action => 'add',
                    values => [ 'permit_sasl_authenticated' ],
                    after  => qr/permit_mynetworks/
                },
                smtpd_recipient_restrictions          => {
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
