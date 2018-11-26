=head1 NAME

 iMSCP::Server::ftpd::proftpd::installer - i-MSCP Proftpd Server implementation

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

package iMSCP::Server::ftpd::proftpd::installer;

use strict;
use warnings;
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Config;
use iMSCP::Crypt qw/ ALNUM randomStr /;
use iMSCP::Debug qw/ debug error /;
use iMSCP::InputValidation qw/
    isOneOfStringsInList isValidUsername isStringNotInList isValidPassword isAvailableSqlUser isValidNumberRange isNumberInRange
/;
use iMSCP::Execute 'execute';
use iMSCP::File;
use iMSCP::Getopt;
use iMSCP::Server::ftpd::proftpd;
use iMSCP::Server::sqld;
use iMSCP::TemplateParser 'processByRef';
use iMSCP::Umask '$UMASK';
use parent 'iMSCP::Common::Singleton';

%::sqlUsers = () unless %::sqlUsers;

=head1 DESCRIPTION

 Installer for the i-MSCP Poftpd Server implementation.

=head1 PUBLIC METHODS

=over 4

=item registerInstallerDialogs( $dialogs )

 See iMSCP::Installer::AbstractActions::registerInstallerDialogs()

=cut

sub registerInstallerDialogs
{
    my ( $self, $dialogs ) = @_;

    push @{ $dialogs },
        sub { $self->_askForSqlUser( @_ ) },
        sub { $self->_askForPassivePortRange( @_ ) };
    0;
}

=item install( )

 See iMSCP::Installer::AbstractActions::install()

=cut

sub install
{
    my ( $self ) = @_;

    my $rs = $self->_bkpConfFile( $self->{'config'}->{'FTPD_CONF_FILE'} );
    $rs ||= $self->_setVersion();
    $rs ||= $self->_setupDatabase();
    $rs ||= $self->_buildConfigFile();
    $rs ||= $self->_oldEngineCompatibility();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Server::ftpd::proftpd::installer

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'ftpd'} = iMSCP::Server::ftpd::proftpd->getInstance();
    $self->{'eventManager'} = $self->{'ftpd'}->{'eventManager'};
    $self->{'cfgDir'} = $self->{'ftpd'}->{'cfgDir'};
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'wrkDir'} = "$self->{'cfgDir'}/working";
    $self->{'config'} = $self->{'ftpd'}->{'config'};
    $self;
}

=item _askForSqlUser( $dialog )

 Ask for ProFTPD SQL user

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForSqlUser
{
    my ( $self, $dialog ) = @_;

    my $masterSqlUser = ::setupGetQuestion( 'DATABASE_USER' );
    my $dbUser = ::setupGetQuestion( 'FTPD_SQL_USER', $self->{'config'}->{'DATABASE_USER'} || 'imscp_srv_user' );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $dbPass = ::setupGetQuestion(
        'FTPD_SQL_PASSWORD', iMSCP::Getopt->preseed ? randomStr( 16, ALNUM ) : $self->{'config'}->{'DATABASE_PASSWORD'}
    );
    $iMSCP::InputValidation::lastValidationError = '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'alternatives', 'all' ] ) || !isValidUsername( $dbUser )
        || !isStringNotInList( $dbUser, 'root', 'debian-sys-maint', $masterSqlUser, 'vlogger_user' ) || !isValidPassword( $dbPass )
        || !isAvailableSqlUser( $dbUser )
    ) {
        Q1:
        do {
            ( my $rs, $dbUser ) = $dialog->string( <<"EOF", $dbUser );
$iMSCP::InputValidation::lastValidationError
Please enter a username for the ProFTPD SQL user:
\\Z \\Zn
EOF
            return $rs unless $rs < 30;
        } while !isValidUsername( $dbUser ) || !isStringNotInList( $dbUser, 'root', 'debian-sys-maint', $masterSqlUser, 'vlogger_user' )
            || !isAvailableSqlUser( $dbUser );

        unless ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
            do {
                ( my $rs, $dbPass ) = $dialog->string( <<"EOF", $dbPass || randomStr( 16, ALNUM ));
$iMSCP::InputValidation::lastValidationError
Please enter a password for the ProFTPD SQL user:
\\Z \\Zn
EOF
                goto Q1 if $rs == 30;
                return $rs if $rs == 50;
            } while !isValidPassword( $dbPass );

            $::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
        } else {
            $dbPass = $::sqlUsers{$dbUser . '@' . $dbUserHost};
        }
    } elsif ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
        $dbPass = $::sqlUsers{$dbUser . '@' . $dbUserHost};
    } else {
        $::sqlUsers{$dbUser . '@' . $dbUserHost} = $dbPass;
    }

    ::setupSetQuestion( 'FTPD_SQL_USER', $dbUser );
    ::setupSetQuestion( 'FTPD_SQL_PASSWORD', $dbPass );
    0;
}

=item _askForPassivePortRange( $dialog )

 Ask for ProtFTPD port range to use for passive data transfers

 Param iMSCP::Dialog $dialog
 Return int 0 (NEXT), 30 (BACK), 50 (ESC)

=cut

sub _askForPassivePortRange
{
    my ( $self, $dialog ) = @_;

    my $passivePortRange = ::setupGetQuestion( 'FTPD_PASSIVE_PORT_RANGE', $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'} );
    my ( $startOfRange, $endOfRange );
    $iMSCP::InputValidation::lastValidationError = '';

    if ( !isValidNumberRange( $passivePortRange, \$startOfRange, \$endOfRange ) || !isNumberInRange( $startOfRange, 32768, 60999 )
        || !isNumberInRange( $endOfRange, $startOfRange, 60999 )
        || isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'ftpd', 'alternatives', 'all' ] )
    ) {
        $passivePortRange = '32768 60999' unless $startOfRange && $endOfRange;

        do {
            ( my $rs, $passivePortRange ) = $dialog->string( <<"EOF", $passivePortRange );
$iMSCP::InputValidation::lastValidationError
Please choose the passive port range for ProFTPD.

If you're behind a NAT, you must forward these ports to this server.
\\Z \\Zn
EOF
            return $rs unless $rs < 30;
        } while !isValidNumberRange( $passivePortRange, \$startOfRange, \$endOfRange ) || !isNumberInRange( $startOfRange, 32768, 60999 )
            || !isNumberInRange( $endOfRange, $startOfRange, 60999 );

        $passivePortRange = "$startOfRange $endOfRange";
    }

    $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'} = $passivePortRange;
    0;
}

=item _bkpConfFile( )

 Backup file

 Return int 0 on success, other on failure

=cut

sub _bkpConfFile
{
    my ( $self, $cfgFile ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFtpdBkpConfFile', $cfgFile );
    return $rs if $rs;

    if ( -f $cfgFile ) {
        my $file = iMSCP::File->new( filename => $cfgFile );
        my ( $filename, undef, $suffix ) = fileparse( $cfgFile );

        unless ( -f "$self->{'bkpDir'}/$filename$suffix.system" ) {
            $rs = $file->copyFile( "$self->{'bkpDir'}/$filename$suffix.system", { preserve => 'no' } );
            return $rs if $rs;
        } else {
            $rs = $file->copyFile( "$self->{'bkpDir'}/$filename$suffix." . time, { preserve => 'no' } );
            return $rs if $rs;
        }
    }

    $self->{'eventManager'}->trigger( 'afterFtpdBkpConfFile', $cfgFile );
}

=item _setVersion

 Set version

 Return int 0 on success, other on failure

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $rs = execute( 'proftpd -v', \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    if ( $stdout !~ m%([\d.]+)% ) {
        error( "Couldn't find ProFTPD version from `proftpd -v` command output." );
        return 1;
    }

    $self->{'config'}->{'PROFTPD_VERSION'} = $1;
    debug( "ProFTPD version set to: $1" );
    0;
}

=item _setupDatabase( )

 Setup database

 Return int 0 on success, other or die on failure

=cut

sub _setupDatabase
{
    my ( $self ) = @_;

    my $dbName = ::setupGetQuestion( 'DATABASE_NAME' );
    my $dbUser = ::setupGetQuestion( 'FTPD_SQL_USER' );
    my $dbUserHost = ::setupGetQuestion( 'DATABASE_USER_HOST' );
    my $oldDbUserHost = $::imscpOldConfig{'DATABASE_USER_HOST'};
    my $dbPass = ::setupGetQuestion( 'FTPD_SQL_PASSWORD' );
    my $dbOldUser = $self->{'config'}->{'DATABASE_USER'};

    my $rs = $self->{'eventManager'}->trigger( 'beforeFtpdSetupDb', $dbUser, $dbPass );
    return $rs if $rs;

    my $sqlServer = iMSCP::Server::sqld->factory();

    # Drop old SQL user if required
    for my $sqlUser ( $dbOldUser, $dbUser ) {
        next unless $sqlUser;

        for my $host ( $dbUserHost, $oldDbUserHost ) {
            next if !$host || exists $::sqlUsers{$sqlUser . '@' . $host} && !defined $::sqlUsers{$sqlUser . '@' . $host};
            $sqlServer->dropUser( $sqlUser, $host );
        }
    }

    # Create SQL user if required
    if ( defined $::sqlUsers{$dbUser . '@' . $dbUserHost} ) {
        debug( sprintf( 'Creating %s@%s SQL user', $dbUser, $dbUserHost ));
        $sqlServer->createUser( $dbUser, $dbUserHost, $dbPass );
        $::sqlUsers{$dbUser . '@' . $dbUserHost} = undef;
    }

    {
        my $rdbh = $self->{'dbh'}->getRawDb();
        local $rdbh->{'RaiseError'} = TRUE;

        # Give required privileges to this SQL user
        # No need to escape wildcard characters. See https://bugs.mysql.com/bug.php?id=18660
        my $quotedDbName = $rdbh->quote_identifier( $dbName );
        for my $table ( 'ftp_users', 'ftp_group' ) {
            $rdbh->do( "GRANT SELECT ON $quotedDbName.$table TO ?\@?", undef, $dbUser, $dbUserHost );
        }

        for my $table ( 'quotalimits', 'quotatallies' ) {
            $rdbh->do( "GRANT SELECT, INSERT, UPDATE ON $quotedDbName.$table TO ?\@?", undef, $dbUser, $dbUserHost );
        }

        $self->{'config'}->{'DATABASE_USER'} = $dbUser;
        $self->{'config'}->{'DATABASE_PASSWORD'} = $dbPass;
    }

    $self->{'eventManager'}->trigger( 'afterFtpSetupDb', $dbUser, $dbPass );
}

=item _buildConfigFile( )

 Build configuration file

 Return int 0 on success, other on failure

=cut

sub _buildConfigFile
{
    my ( $self ) = @_;

    # Escape any double-quotes and backslash (see #IP-1330)
    ( my $dbUser = $self->{'config'}->{'DATABASE_USER'} ) =~ s%("|\\)%\\$1%g;
    ( my $dbPass = $self->{'config'}->{'DATABASE_PASSWORD'} ) =~ s%("|\\)%\\$1%g;

    my $data = {
        IPV6_SUPPORT            => ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ? 'on' : 'off',
        HOSTNAME                => ::setupGetQuestion( 'SERVER_HOSTNAME' ),
        DATABASE_NAME           => ::setupGetQuestion( 'DATABASE_NAME' ),
        DATABASE_HOST           => ::setupGetQuestion( 'DATABASE_HOST' ),
        DATABASE_PORT           => ::setupGetQuestion( 'DATABASE_PORT' ),
        DATABASE_USER           => qq/"$dbUser"/,
        DATABASE_PASS           => qq/"$dbPass"/,
        FTPD_MIN_UID            => $self->{'config'}->{'MIN_UID'},
        FTPD_MIN_GID            => $self->{'config'}->{'MIN_GID'},
        FTPD_PASSIVE_PORT_RANGE => $self->{'config'}->{'FTPD_PASSIVE_PORT_RANGE'},
        CONF_DIR                => $::imscpConfig{'CONF_DIR'},
        CERTIFICATE             => 'imscp_services',
        SERVER_IDENT_MESSAGE    => '"[' . ::setupGetQuestion( 'SERVER_HOSTNAME' ) . '] i-MSCP FTP server."',
        TLSOPTIONS              => 'NoCertRequest NoSessionReuseRequired',
        MAX_INSTANCES           => $self->{'config'}->{'MAX_INSTANCES'},
        MAX_CLIENT_PER_HOST     => $self->{'config'}->{'MAX_CLIENT_PER_HOST'}
    };

    my $rs = $self->{'eventManager'}->trigger( 'onLoadTemplate', 'proftpd', 'proftpd.conf', \my $cfgTpl, $data );
    return $rs if $rs;

    unless ( defined $cfgTpl ) {
        $cfgTpl = iMSCP::File->new( filename => "$self->{'cfgDir'}/proftpd.conf" )->get();
        return 1 unless defined $cfgTpl;
    }

    $rs = $self->{'eventManager'}->trigger( 'beforeFtpdBuildConf', \$cfgTpl, 'proftpd.conf' );
    return $rs if $rs;

    if ( ::setupGetQuestion( 'SERVICES_SSL_ENABLED' ) eq 'yes' ) {
        $cfgTpl .= <<'EOF';

# SSL configuration
<Global>
<IfModule mod_tls.c>
  TLSEngine                on
  TLSRequired              off
  TLSLog                   /var/log/proftpd/ftp_ssl.log
  TLSOptions               {TLSOPTIONS}
  TLSRSACertificateFile    {CONF_DIR}/{CERTIFICATE}.pem
  TLSRSACertificateKeyFile {CONF_DIR}/{CERTIFICATE}.pem
  TLSVerifyClient          off
</IfModule>
</Global>
<IfModule mod_tls.c>
  TLSProtocol TLSv1
</IfModule>
EOF
    }

    my $baseServerIp = ::setupGetQuestion( 'BASE_SERVER_IP' );
    my $baseServerPublicIp = ::setupGetQuestion( 'BASE_SERVER_PUBLIC_IP' );

    if ( $baseServerIp ne $baseServerPublicIp ) {
        my @virtualHostIps = grep ($_ ne '0.0.0.0', ( '127.0.0.1', ( ::setupGetQuestion( 'IPV6_SUPPORT' ) eq 'yes' ? '::1' : () ), $baseServerIp ));
        $cfgTpl .= <<"EOF";

# Server behind NAT - Advertise public IP address
MasqueradeAddress $baseServerPublicIp

# VirtualHost for local access (No IP masquerading)
<VirtualHost @virtualHostIps>
    ServerName "{HOSTNAME}.local"
</VirtualHost>
EOF
    }

    processByRef( $data, \$cfgTpl );

    $rs = $self->{'eventManager'}->trigger( 'afterFtpdBuildConf', \$cfgTpl, 'proftpd.conf' );
    return $rs if $rs;

    local $UMASK = 027; # proftpd.conf file must not be created/copied world-readable
    my $file = iMSCP::File->new( filename => "$self->{'wrkDir'}/proftpd.conf" );
    $file->set( $cfgTpl );
    $rs = $file->save();
    $rs ||= $file->owner( $::imscpConfig{'ROOT_USER'}, $::imscpConfig{'ROOT_GROUP'} );
    $rs ||= $file->mode( 0640 );
    $rs ||= $file->copyFile( $self->{'config'}->{'FTPD_CONF_FILE'} );
    return $rs if $rs;

    if ( -f "$self->{'config'}->{'FTPD_CONF_DIR'}/modules.conf" ) {
        $file = iMSCP::File->new( filename => "$self->{'config'}->{'FTPD_CONF_DIR'}/modules.conf" );
        my $fileC = $file->getAsRef();
        return 1 unless defined $fileC;

        ${ $fileC } =~ s/^(LoadModule\s+mod_tls_memcache.c)/#$1/m;
        $rs ||= $file->save();
    }

    $rs;
}

=item _oldEngineCompatibility( )

 Remove old files

 Return int 0 on success, other on failure

=cut

sub _oldEngineCompatibility
{
    my ( $self ) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeFtpdOldEngineCompatibility' );
    return $rs if $rs;

    if ( -f "$self->{'cfgDir'}/proftpd.old.data" ) {
        $rs = iMSCP::File->new( filename => "$self->{'cfgDir'}/proftpd.old.data" )->delFile();
        return $rs if $rs;
    }

    $self->{'eventManager'}->trigger( 'afterFtpdOldEngineCompatibility' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
