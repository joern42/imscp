=head1 NAME

 iMSCP::Servers::Mta::Postfix::Abstract - i-MSCP Postfix server abstract implementation

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

package iMSCP::Servers::Mta::Postfix::Abstract;

use strict;
use warnings;
use autouse Fcntl => qw/ O_RDONLY /;
use autouse 'iMSCP::Dialog::InputValidation' => qw/ isOneOfStringsInList isStringInList /;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Config iMSCP::Getopt iMSCP::Net iMSCP::SystemGroup iMSCP::SystemUser Tie::File /;
use File::Basename;
use File::Temp;
use File::Spec;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute executeNoWait /;
use iMSCP::File;
use Scalar::Defer qw/ lazy /;
use parent 'iMSCP::Servers::Mta';

=head1 DESCRIPTION

 i-MSCP Postfix server abstract implementation.

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( )

 See iMSCP::Servers::Abstract::registerSetupListeners()

 Return void, die on failure

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeSetupDialog', sub { push @{ $_[0] }, sub { $self->_askForDatabaseDriver( @_ ) } }, $self->getPriority()
    );
}

=item preinstall( )

 See iMSCP::Servers::Abstract::preinstall()

=cut

sub preinstall
{
    my ( $self ) = @_;

    $self->SUPER::preinstall();
    $self->_createUserAndGroup();
    $self->_makeDirs();

    # If the DB driver has been changed, we need trigger uninstallation of previous one
    if ( length $self->{'old_config'}->{'MTA_DB_DRIVER'} && $self->{'config'}->{'MTA_DB_DRIVER'} ne $self->{'old_config'}->{'MTA_DB_DRIVER'} ) {
        $self->getDbDriver( $self->{'old_config'}->{'MTA_DB_DRIVER'} )->uninstall();
    }

    $self->{'_db'}->preinstall();
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->_setVersion();
    $self->_setDefaultDatabaseType();
    $self->_configure();
    $self->{'_db'}->install();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    $self->{'_db'}->postinstall();
    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            while ( my ( $path, $type ) = each( %{ $self->{'_postmap'} } ) ) {
                # We need test for database existence as it can have been removed
                next unless -f $path;
                $self->postmap( $path, $type );
            }
        },
        $self->getPriority()
    );
    $self->SUPER::postinstall();
}

=item uninstall( )

 See iMSCP::Servers::Abstract::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->{'_db'}->uninstall();
    $self->_removeUser();
    $self->_removeFiles();
}

=item setBackendPermissions( )

 See iMSCP::Servers::Abstract::SetBackendPermissions()

=cut

sub setBackendPermissions
{
    my ( $self ) = @_;
    setRights( $self->{'config'}->{'MTA_MAIN_CONF_FILE'}, {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'},
        mode  => '0644'
    } );
    setRights( $self->{'config'}->{'MTA_MASTER_CONF_FILE'}, {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'},
        mode  => '0644'
    } );
    setRights( $self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'}, {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'},
        mode  => '0644'
    } );
    setRights( "$::imscpConfig{'BACKEND_ROOT_DIR'}/messenger", {
        user      => $::imscpConfig{'ROOT_USER'},
        group     => $::imscpConfig{'IMSCP_GROUP'}, # FIXME WTF ???
        dirmode   => '0750',
        filemode  => '0750',
        recursive => TRUE
    } );
    setRights( $self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}, {
        user      => $self->{'config'}->{'MTA_MAILBOX_UID_NAME'},
        group     => $self->{'config'}->{'MTA_MAILBOX_GID_NAME'},
        dirmode   => '0750',
        filemode  => '0640',
        recursive => iMSCP::Getopt->fixPermissions
    } );
    setRights( $self->{'config'}->{'MAIL_LOG_CONVERT_PATH'}, {
        user  => $::imscpConfig{'ROOT_USER'},
        group => $::imscpConfig{'ROOT_GROUP'},
        mode  => '0750'
    } );
    $self->{'_db'}->setBackendPermissions();
}

=item getServerName( )

 See iMSCP::Servers::Abstract::getServerName()

=cut

sub getServerName
{
    my ( $self ) = @_;

    'Postfix';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ( $self ) = @_;

    sprintf( 'Postfix %s', $self->getVersion());
}

=item getVersion( )

 See iMSCP::Servers::Abstract::getVersion()

=cut

sub getVersion
{
    my ( $self ) = @_;

    $self->{'config'}->{'MTA_VERSION'};
}

=item addDomain( \%moduleData )

 See iMSCP::Servers::Mta::addDomain()

=cut

sub addDomain
{
    my ( $self, $moduleData ) = @_;

    # Do not list SERVER_HOSTNAME in BOTH mydestination and virtual_mailbox_domains
    return if $moduleData->{'DOMAIN_NAME'} eq $::imscpConfig{'SERVER_HOSTNAME'};

    $self->{'eventManager'}->trigger( 'beforePostfixAddDomain', $moduleData );

    if ( $moduleData->{'EXTERNAL_MAIL'} ) {
        # Mails for this domain are managed by external server
        $self->{'_db'}->delete( 'virtual_mailbox_domains', $moduleData->{'DOMAIN_NAME'} );
        $self->{'_db'}->add( 'relay_domains', $moduleData->{'DOMAIN_NAME'} );
    } else {
        # Mails for this domain are managed by this server
        $self->{'_db'}->delete( 'relay_domains', $moduleData->{'DOMAIN_NAME'} );
        $self->{'_db'}->add( 'virtual_mailbox_domains', $moduleData->{'DOMAIN_NAME'} );
    }

    $self->{'eventManager'}->trigger( 'afterPostfixAddDomain', $moduleData );
}

=item disableDomain( \%moduleData )

 See iMSCP::Servers::Mta::disableDomain()

=cut

sub disableDomain
{
    my ( $self, $moduleData ) = @_;

    return if $moduleData->{'DOMAIN_NAME'} eq $::imscpConfig{'SERVER_HOSTNAME'};

    $self->{'eventManager'}->trigger( 'beforePostfixDisableDomain', $moduleData );
    $self->{'_db'}->delete( 'virtual_mailbox_domains', $moduleData->{'DOMAIN_NAME'} );
    $self->{'_db'}->delete( 'relay_domains', $moduleData->{'DOMAIN_NAME'} );
    $self->{'eventManager'}->trigger( 'afterPostfixDisableDomain', $moduleData );
}

=item deleteDomain( \%moduleData )

 See iMSCP::Servers::Mta::deleteDomain()

=cut

sub deleteDomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixDeleteDomain', $moduleData );
    $self->{'_db'}->delete( 'virtual_mailbox_domains', $moduleData->{'DOMAIN_NAME'} );
    $self->{'_db'}->delete( 'relay_domains', $moduleData->{'DOMAIN_NAME'} );
    iMSCP::Dir->new( dirname => "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}" )->remove();
    $self->{'eventManager'}->trigger( 'afterPostfixDeleteDomain', $moduleData );
}

=item addSubdomain( \%moduleData )

 See iMSCP::Servers::Mta::addSubdomain()

=cut

sub addSubdomain
{
    my ( $self, $moduleData ) = @_;

    # Do not list SERVER_HOSTNAME in BOTH mydestination and virtual_mailbox_domains
    return if $moduleData->{'DOMAIN_NAME'} eq $::imscpConfig{'SERVER_HOSTNAME'};

    $self->{'eventManager'}->trigger( 'beforePostfixAddSubdomain', $moduleData );

    if ( $moduleData->{'EXTERNAL_MAIL'} ) {
        # Mails for this subdomain are managed by external server
        $self->{'_db'}->delete( 'virtual_mailbox_domains', $moduleData->{'DOMAIN_NAME'} );
    } else {
        # Mails for this subdomain are managed by this server
        $self->{'_db'}->add( 'virtual_mailbox_domains', $moduleData->{'DOMAIN_NAME'} );
    }

    $self->{'eventManager'}->trigger( 'afterPostfixAddSubdomain', $moduleData );
}

=item disableSubdomain( \%moduleData )

 See iMSCP::Servers::Mta::disableSubdomain()

=cut

sub disableSubdomain
{
    my ( $self, $moduleData ) = @_;

    return if $moduleData->{'DOMAIN_NAME'} eq $::imscpConfig{'SERVER_HOSTNAME'};

    $self->{'eventManager'}->trigger( 'beforePostfixDisableSubdomain', $moduleData );
    $self->{'_db'}->delete( 'virtual_mailbox_domains', $moduleData->{'DOMAIN_NAME'} );
    $self->{'eventManager'}->trigger( 'afterPostfixDisableSubdomain', $moduleData );
}

=item deleteSubdomain( \%moduleData )

 See iMSCP::Servers::Mta::deleteSubdomain()

=cut

sub deleteSubdomain
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixDeleteSubdomain', $moduleData );
    $self->{'_db'}->delete( 'virtual_mailbox_domains', $moduleData->{'DOMAIN_NAME'} );
    iMSCP::Dir->new( dirname => "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}" )->remove();
    $self->{'eventManager'}->trigger( 'afterPostfixDeleteSubdomain', $moduleData );
}

=item addMail( \%moduleData )

 See iMSCP::Servers::Mta::addMail()

=cut

sub addMail
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixAddMail', $moduleData );

    if ( $moduleData->{'MAIL_CATCHALL'} ) {
        $self->{'_db'}->add( 'virtual_alias_maps', $moduleData->{'MAIL_ADDR'}, $moduleData->{'MAIL_CATCHALL'} );
    } else {
        my $isMailAcc = index( $moduleData->{'MAIL_TYPE'}, '_mail' ) != -1 && $moduleData->{'DOMAIN_NAME'} ne $::imscpConfig{'SERVER_HOSTNAME'};
        my $isForwardAccount = index( $moduleData->{'MAIL_TYPE'}, '_forward' ) != -1;
        return unless $isMailAcc || $isForwardAccount;

        $self->{'_db'}->delete( 'virtual_mailbox_maps', $moduleData->{'MAIL_ADDR'} );
        $self->{'_db'}->delete( 'virtual_alias_maps', $moduleData->{'MAIL_ADDR'} );

        if ( $isMailAcc ) {
            my $maildir = "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}";

            # Create mailbox
            for my $dir ( $moduleData->{'DOMAIN_NAME'}, "$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}" ) {
                iMSCP::Dir->new( dirname => "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$dir" )->make( {
                    user           => $self->{'config'}->{'MTA_MAILBOX_UID_NAME'},
                    group          => $self->{'config'}->{'MTA_MAILBOX_GID_NAME'},
                    mode           => 0750,
                    fixpermissions => iMSCP::Getopt->fixPermissions
                } );
            }
            for my $dir ( qw/ cur new tmp / ) {
                iMSCP::Dir->new( dirname => "$maildir/$dir" )->make( {
                    user           => $self->{'config'}->{'MTA_MAILBOX_UID_NAME'},
                    group          => $self->{'config'}->{'MTA_MAILBOX_GID_NAME'},
                    mode           => 0750,
                    fixpermissions => iMSCP::Getopt->fixPermissions
                } );
            }

            # Add virtual mailbox map entry
            $self->{'_db'}->add( 'virtual_mailbox_maps', "$moduleData->{'MAIL_ADDR'}\t$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}/" );
        } else {
            iMSCP::Dir->new(
                dirname => "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}"
            )->remove();
        }

        # Add virtual alias map entry
        $self->{'_db'}->add(
            'virtual_alias_maps',
            $moduleData->{'MAIL_ADDR'}, # Recipient
            join ',', (
                # Mail account only case:
                #  Postfix lookup in `virtual_alias_maps' first. Thus, if there
                #  is a catchall defined for the domain, any mail for the mail
                #  account will be catched by the catchall. To prevent this
                #  behavior, we must also add an entry in the virtual alias map.
                #
                # Forward + mail account case:
                #  we want keep local copy of inbound mails
                ( $isMailAcc ? $moduleData->{'MAIL_ADDR'} : () ),

                # Add forward addresses in case of forward account
                ( $isForwardAccount ? $moduleData->{'MAIL_FORWARD'} : () ),

                # Add autoresponder entry if it is enabled for this account
                ( $moduleData->{'MAIL_HAS_AUTO_RESPONDER'} ? "$moduleData->{'MAIL_ACC'}\@imscp-arpl.$moduleData->{'DOMAIN_NAME'}" : () )
            )
        );

        # Add transport map entry for autoresponder if needed
        if ( $moduleData->{'MAIL_HAS_AUTO_RESPONDER'} ) {
            $self->{'_db'}->add( 'transport_maps', "$moduleData->{'MAIL_ACC'}\@imscp-arpl.$moduleData->{'DOMAIN_NAME'}", "\timscp-arpl:" );
        } else {
            $self->{'_db'}->delete( 'transport_maps', "$moduleData->{'MAIL_ACC'}\@imscp-arpl.$moduleData->{'DOMAIN_NAME'}" );
        }
    }

    $self->{'eventManager'}->trigger( 'afterPostfixAddMail', $moduleData );
}

=item disableMail( \%moduleData )

 See iMSCP::Servers::Mta::disableMail()

=cut

sub disableMail
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixDisableMail', $moduleData );
    $self->{'_db'}->delete( 'virtual_alias_maps', "$moduleData->{'MAIL_ADDR'}" );

    return if $moduleData->{'MAIL_CATCHALL'};

    $self->{'_db'}->delete( 'virtual_mailbox_maps', $moduleData->{'MAIL_ADDR'} );
    $self->{'_db'}->delete( 'transport_maps', "$moduleData->{'MAIL_ACC'}\@imscp-arpl.$moduleData->{'DOMAIN_NAME'}" );
    $self->{'eventManager'}->trigger( 'afterPostfixDisableMail', $moduleData );
}

=item deleteMail( \%moduleData )

 See iMSCP::Servers::Mta::deleteMail()

=cut

sub deleteMail
{
    my ( $self, $moduleData ) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixDeleteMail', $moduleData );
    $self->{'_db'}->delete( 'virtual_alias_maps', $moduleData->{'MAIL_ADDR'} );

    return if $moduleData->{'MAIL_CATCHALL'};

    $self->{'_db'}->delete( 'virtual_mailbox_maps', $moduleData->{'MAIL_ADDR'} );
    $self->{'_db'}->delete( 'transport_maps', "$moduleData->{'MAIL_ACC'}\@imscp-arpl.$moduleData->{'DOMAIN_NAME'}" );
    iMSCP::Dir->new( dirname => "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}" )->remove();
    $self->{'eventManager'}->trigger( 'afterPostfixDeleteMail', $moduleData );
}

=item getTraffic( \%trafficDb [, $logFile, \%trafficIndexDb ] )

 See iMSCP::Servers::Mta::getTraffic()

=cut

sub getTraffic
{
    my ( $self, $trafficDb, $logFile, $trafficIndexDb ) = @_;
    $logFile ||= "$::imscpConfig{'TRAFF_LOG_DIR'}/$::imscpConfig{'MAIL_TRAFF_LOG'}";

    unless ( -f $logFile ) {
        debug( sprintf( "SMTP %s log file doesn't exist. Skipping...", $logFile ));
        return;
    }

    debug( sprintf( 'Processing SMTP %s log file', $logFile ));

    # We use an index database to keep trace of the last processed logs
    $trafficIndexDb or die %{ $trafficIndexDb }, 'iMSCP::Config', filename => "$::imscpConfig{'IMSCP_HOMEDIR'}/traffic_index.db", nocroak => TRUE;
    my ( $idx, $idxContent ) = ( $trafficIndexDb->{'smtp_lineNo'} || 0, $trafficIndexDb->{'smtp_lineContent'} );

    # Extract and standardize SMTP logs in temporary file, using
    # maillogconvert.pl script
    my $stdLogFile = File::Temp->new();
    $stdLogFile->close();
    my $stderr;
    execute( "nice -n 19 ionice -c2 -n7 /usr/local/sbin/maillogconvert.pl standard < $logFile > $stdLogFile", undef, \$stderr ) == 0 or die(
        sprintf( "Couldn't standardize SMTP logs: %s", $stderr || 'Unknown error' )
    );

    tie my @logs, 'Tie::File', "$stdLogFile", mode => O_RDONLY, memory => 0 or die( sprintf( "Couldn't tie %s file in read-only mode", $logFile ));

    if ( exists $logs[$idx] && $logs[$idx] eq $idxContent ) {
        debug( sprintf( 'Skipping SMTP logs that were already processed (lines %d to %d)', 1, ++$idx ));
    } elsif ( length $idxContent && substr( $logFile, -2 ) ne '.1' ) {
        debug( 'Log rotation has been detected. Processing last rotated log file first' );
        $self->getTraffic( $trafficDb, $logFile . '.1', $trafficIndexDb );
        $idx = 0;
    }

    if ( $#logs < $idx ) {
        debug( 'No new SMTP logs found for processing' );
        return;
    }

    debug( sprintf( 'Processing SMTP logs (lines %d to %d)', $idx+1, $#logs+1 ));

    # Extract SMTP traffic data
    #
    # Log line example
    # date       hour     from            to            relay_s            relay_r            proto  extinfo code size
    # 2017-04-17 13:31:50 from@domain.tld to@domain.tld relay_s.domain.tld relay_r.domain.tld SMTP   -       1    1001
    my $regexp = qr/\@(?<from>[^\s]+)[^\@]+\@(?<to>[^\s]+)\s+(?<relay_s>[^\s]+)\s+(?<relay_r>[^\s]+).*?(?<size>\d+)$/;

    # In term of memory usage, C-Style loop provide better results than using 
    # range operator in Perl-Style loop: for( @logs[$idx .. $#logs] ) ...
    for ( my $i = $idx; $i <= $#logs; $i++ ) {
        next unless $logs[$i] =~ /$regexp/;
        $trafficDb->{$+{'from'}} += $+{'size'} if exists $trafficDb->{$+{'from'}};
        $trafficDb->{$+{'to'}} += $+{'size'} if exists $trafficDb->{$+{'to'}};
    }

    return if substr( $logFile, -2 ) eq '.1';

    $trafficIndexDb->{'smtp_lineNo'} = $#logs;
    $trafficIndexDb->{'smtp_lineContent'} = $logs[$#logs];
}

=item postmap( $lookupTable [, $lookupTableType = $self->{'config}->{'MTA_DB_DEFAULT_TYPE'} [, $delayed = FALSE ] ] )

 Provides an interface to POSTMAP(1) for creating/updating Postfix databases (lookup tables)

 Param string $lookupTable Full path to lookup table
 Param string $lookupTableType OPTIONAL Lookup table type
 Param bool $delayed Flag indicating whether creation/update of the give lookup table must be delayed
 Return void, die on failure
 FIXME: Relying on default DB type will pose problem when the MySQL database type will be available

=cut

sub postmap
{
    my ( $self, $lookupTable, $lookupTableType, $delayed ) = @_;
    $lookupTableType //= $self->{'_db'}->getDbType();

    File::Spec->file_name_is_absolute( $lookupTable ) or die( 'Absolute lookup table file expected' );

    grep ($lookupTableType eq lc $_, keys %{ $self->getAvailableDbDrivers() } ) or die(
        sprintf( "Unknown '%s' database type. Available types are: %s", $lookupTableType, join ', ', keys %{ $self->getAvailableDbDrivers() } )
    );

    if ( $delayed ) {
        $self->{'_postmap'}->{$lookupTable} //= $lookupTableType;
        return;
    }

    my $rs = execute( [ 'postmap', "$lookupTableType:$lookupTable" ], \my $stdout, \my $stderr );
    debug( $stdout ) if length $stdout;
    !$rs or die( $stderr || 'Unknown error' );
}

=item postconf( $conffile, %params )

 Provides an interface to POSTCONF(1) for editing Postfix parameters in the main.cf configuration file

 Param hash %params A hash where each key is a Postfix parameter name and the value, a hash describing in order:
  - action : Action to be performed (add|replace|remove) -- Default replace
  - values : An array containing parameter value(s) to add, replace or remove. For values to be removed, both strings and Regexp are supported.
  - empty  : OPTIONAL Flag that allows to force adding of empty parameter
  - before : OPTIONAL Option that allows to add parameter value(s) before the given value (expressed as a Regexp)
  - after  : OPTIONAL Option that allows to add parameter value(s) after the given value (expressed as a Regexp)

  `replace' action versus `remove' action
    The `replace' action replace all values of the given parameter while the `remove' action only remove the specified values in the parameter.
    Note that when the result is an empty value, the parameter is removed from the configuration file unless the `empty' flag has been specified.

  `before' and `after' options:
    The `before' and `after' options are only relevant for the `add' action. Note also that the `before' option has a highter precedence than the
    `after' option.
  
  Unknown postfix parameters
    Unknown Postfix parameter are silently ignored

  Usage example:

    Adding parameter values

    Let's assume that we want add both, the `check_client_access <table>' value and the `check_recipient_access <table>' value to the
    `smtpd_recipient_restrictions' parameter, before the `check_policy_service ...' service. The following would do the job:

    iMSCP::Servers::Mta::Postfix::Abstract->getInstance(
        (
            smtpd_recipient_restrictions => {
                action => 'add',
                values => [ 'check_client_access <table>', 'check_recipient_access <table>' ],
                before => qr/check_policy_service\s+.*/,
            }
        )
    );
 
    Removing value portion of parameters

    iMSCP::Servers::Mta::Postfix::Abstract->getInstance(
        (
            smtpd_milters     => {
                action => 'remove',
                values => [ qr%\Qunix:/opendkim/opendkim.sock\E% ] # Using Regexp
            },
            non_smtpd_milters => {
                action => 'remove',
                values => [ 'unix:/opendkim/opendkim.sock' ] # Using string
            }
        )
    )

 Return void, die on failure

=cut

sub postconf
{
    my ( $self, %params ) = @_;

    %params or croak( 'Missing parameters ' );

    my @pToDel = ();
    my $conffile = $self->{'config'}->{'MTA_CONF_DIR'};
    my $time = time();

    # Avoid POSTCONF(1) being slow by waiting 2 seconds before next processing
    # See https://groups.google.com/forum/#!topic/list.postfix.users/MkhEqTR6yRM
    utime $time, $time-2, $self->{'config'}->{'MTA_MAIN_CONF_FILE'} or die(
        sprintf( "Couldn't touch %s file: %s", $self->{'config'}->{'MTA_MAIN_CONF_FILE'} )
    );

    my ( $stdout, $stderr );
    executeNoWait(
        [ 'postconf', '-c', $conffile, keys %params ],
        sub {
            return unless my ( $p, $v ) = $_[0] =~ /^([^=]+)\s+=\s*(.*)/;

            # In main.cf, separator is either space or comma
            my ( @vls, @rpls ) = ( split( /[,\s]+/, $v ), () );

            defined $params{$p}->{'values'} && ref $params{$p}->{'values'} eq 'ARRAY' or croak(
                sprintf( "Missing or invalid values for the %s parameter. Expects an array of values", $p )
            );

            for $v ( @{ $params{$p}->{'values'} } ) {
                $params{$p}->{'action'} //= 'replace';

                if ( $params{$p}->{'action'} eq 'add' ) {
                    unless ( $params{$p}->{'before'} || $params{$p}->{'after'} ) {
                        next if grep ( $_ eq $v, @vls );
                        push @vls, $v;
                        next;
                    }

                    # If the parameter value already exists, we delete it as someone could want move it
                    @vls = grep ( $_ ne $v, @vls );
                    my $regexp = $params{$p}->{'before'} || $params{$p}->{'after'};
                    ref $regexp eq 'Regexp' or croak( 'Invalid before|after option. Expects a Regexp' );
                    my ( $idx ) = grep ( $vls[$_] =~ /^$regexp$/, 0 .. ( @vls-1 ) );
                    defined $idx ? splice( @vls, ( $params{$p}->{'before'} ? $idx : ++$idx ), 0, $v ) : push @vls, $v;
                } elsif ( $params{$p}->{'action'} eq 'replace' ) {
                    push @rpls, $v;
                } elsif ( $params{$p}->{'action'} eq 'remove' ) {
                    @vls = ref $v eq 'Regexp' ? grep ($_ !~ $v, @vls) : grep ($_ ne $v, @vls);
                } else {
                    croak( sprintf( 'Unknown action %s for the  %s parameter', $params{$p}->{'action'}, $p ));
                }
            }

            my $forceEmpty = $params{$p}->{'empty'};
            $params{$p} = join ' ', @rpls ? @rpls : @vls;

            unless ( $forceEmpty || length $params{$p} ) {
                push @pToDel, $p;
                delete $params{$p};
            }
        },
        sub { $stderr .= shift }
    ) == 0 or die( $stderr || 'Unknown error' );

    if ( %params ) {
        my $cmd = [ 'postconf', '-e', '-c', $conffile ];
        while ( my ( $param, $value ) = each %params ) { push @{ $cmd }, "$param=$value" };
        execute( $cmd, \$stdout, \$stderr ) == 0 or die( $stderr || 'Unknown error' );
        debug( $stdout ) if length $stdout;
    }

    if ( @pToDel ) {
        execute( [ 'postconf', '-X', '-c', $conffile, @pToDel ], \$stdout, \$stderr ) == 0 or die( $stderr || 'Unknown error' );
        debug( $stdout ) if length $stdout;
    };

    $self->{'reload'} ||= 1;
}

=item getAvailableDbDrivers

 Return list of available Postfix database

 Only database driver types that are supported by the distribution and for
 which an i-MSCP implementation is available must be reported.
 
 See the iMSCP::Servers::Mta::Postfix::Driver::Database::* classes.
 
 Returned hashref *MUST* looks as follows:

    {
        CDB   => {
            desc    => 'A read-optimized structure (recommended)',
            class   => 'iMSCP::Servers::Mta::Postfix::Driver::Database::CDB',
            default => TRUE
        },
        BTree => {
            desc  => 'A sorted, balanced tree structure',
            class => 'iMSCP::Servers::Mta::Postfix::Driver::Database::BTree'
        },
        Hash  => {
            desc  => 'An indexed file type based on hashing',
            class => 'iMSCP::Servers::Mta::Postfix::Driver::Database::Hash'
        }
    }

 See also: http://www.postfix.org/DATABASE_README.html#types

 Return hashref List of available database driver types

=cut

sub getAvailableDbDrivers
{
    my ( $self ) = @_;

    die( sprintf( 'The %s class must implement the getAvailableDbDrivers() method', ref $self ));
}

=item getDbDriver( [ $driver = $self->{'config'}->{'MTA_DB_DRIVER'} ] )

 Return instance of the given database driver, default driver if none is provided.

 Param string $driver Database driver name
 Return iMSCP::Servers::Mta::Postfix::Driver::Database::Abstract

=cut

sub getDbDriver
{
    my ( $self, $driver ) = @_;
    $driver //= $self->{'config'}->{'MTA_DB_DRIVER'};

    $self->{'_db_drivers'}->{$driver} //= do {
        eval "require $driver; 1" or die $@;
        $driver->new( mta => $self );
    };
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 See iMSCP::Servers::Mta::_init()

=cut

sub _init
{
    my ( $self ) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    @{ $self }{qw/ restart reload cfgDir _db_drivers _db /} = ( FALSE, FALSE, "$::imscpConfig{'CONF_DIR'}/postfix", {}, lazy { $self->getDbDriver() } );
    $self->SUPER::_init();
}

=item _askForDatabaseDriver( \%dialog )

 Ask for Postfix database driver to use

 Param iMSCP::Dialog \%dialog
 Return int 0 (NEXT), 30 (BACK) or 50 (ESC)
 
=cut

sub _askForDatabaseDriver
{
    my ( $self, $dialog ) = @_;

    my $dbDrivers = $self->getAvailableDbDrivers();
    my ( $defaultDbDriver ) = map { $dbDrivers->{$_}->{'default'} ? $_ : () } keys %{ $dbDrivers };
    my %choices = map { $_ => $dbDrivers->{$_}->{'desc'} } keys %{ $dbDrivers };
    my $class = ::setupGetQuestion(
        'MTA_DB_DRIVER', $self->{'config'}->{'MTA_DB_DRIVER'} || ( iMSCP::Getopt->preseed ? $dbDrivers->{$defaultDbDriver}->{'class'} : '' )
    );
    my ( $value ) = ( grep ($dbDrivers->{$_}->{'class'} eq $class, keys %{ $dbDrivers }) )[0] // '';

    if ( isOneOfStringsInList( iMSCP::Getopt->reconfigure, [ 'mta', 'servers', 'all', 'forced' ] ) || !isStringInList( $value, keys %choices ) ) {
        ( my $rs, $value ) = $dialog->radiolist( <<"EOF", \%choices, ( grep ( $value eq $_, keys %choices ) )[0] || $defaultDbDriver, TRUE );

Please choose the Postfix database driver you want use for lookup tables.

See http://www.postfix.org/DATABASE_README.html for further details.
\\Z \\Zn
EOF
        return $rs unless $rs < 30;
    }

    ::setupSetQuestion( 'MTA_DB_DRIVER', $dbDrivers->{$value}->{'class'} );
    $self->{'config'}->{'MTA_DB_DRIVER'} = $dbDrivers->{$value}->{'class'};
    $self->{'_db'}->setupDialog();
}

=item _createUserAndGroup( )

 Create vmail user and mail group

 Return void, die on failure

=cut

sub _createUserAndGroup
{
    my ( $self ) = @_;

    iMSCP::SystemGroup->getInstance()->addSystemGroup( $self->{'config'}->{'MTA_MAILBOX_GID_NAME'}, TRUE );

    my $systemUser = iMSCP::SystemUser->new(
        username => $self->{'config'}->{'MTA_MAILBOX_UID_NAME'},
        group    => $self->{'config'}->{'MTA_MAILBOX_GID_NAME'},
        comment  => 'vmail user',
        home     => $self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'},
        system   => TRUE
    );
    $systemUser->addSystemUser();
    $systemUser->addToGroup( $::imscpConfig{'IMSCP_GROUP'} );
}

=item _makeDirs( )

 Create directories

 Return void, die on failure

=cut

sub _makeDirs
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => $self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'} )->make( {
        user           => $self->{'config'}->{'MTA_MAILBOX_UID_NAME'},
        group          => $self->{'config'}->{'MTA_MAILBOX_GID_NAME'},
        mode           => 0750,
        fixpermissions => iMSCP::Getopt->fixPermissions
    } );
}

=item _configure( )

 Configure Postfix

 Return void, die on failure

=cut

sub _configure
{
    my ( $self ) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixConfigure' );
    $self->_buildAliasesDb();
    $self->_buildMainCfFile();
    $self->_buildMasterCfFile();
    $self->{'eventManager'}->trigger( 'afterPostfixConfigure' );
}

=item _setVersion( )

 Set Postfix version

 Return void, die on failure

=cut

sub _setVersion
{
    my ( $self ) = @_;

    my $rs = execute( [ 'postconf', '-d', '-h', 'mail_version' ], \my $stdout, \my $stderr );
    debug( $stdout ) if length $stdout;
    !$rs or die( $stderr || 'Unknown error' );
    $stdout =~ /^([\d.]+)/ or die( "Couldn't guess Postfix version from the `postconf -d -h mail_version` command output" );
    $self->{'config'}->{'MTA_VERSION'} = $1;
    debug( sprintf( 'Postfix version set to: %s', $stdout ));
}

=item _setDefaultDatabaseType( )

 Set Postfix default database type

 Return void, die on failure

=cut

sub _setDefaultDatabaseType
{
    my ( $self ) = @_;

    my $rs = execute( [ 'postconf', '-d', '-h', 'default_database_type' ], \my $stdout, \my $stderr );
    debug( $stdout ) if length $stdout;
    !$rs or die( $stderr || 'Unknown error' );
    length $stdout or die( "Couldn't guess default Postfix database type from the `postconf -d -h default_database_type` command output" );
    chomp( $stdout );
    $self->{'config'}->{'MTA_DB_DEFAULT_TYPE'} = $stdout;
    debug( sprintf( 'Postfix default database type set to: %s', $stdout ));
}

=item _buildAliasesDb( )

 Build aliases database

 Return void, die on failure

=cut

sub _buildAliasesDb
{
    my ( $self ) = @_;

    my $dbDir = dirname( $self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'} );
    my $dbName = basename( $self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'} );

    # Remove any previous database (covers case where default database type has been changed)
    iMSCP::Dir->new( dirname => $dbDir )->clear( qr/\Q$dbName.\E(?:c?db)$/ );

    $self->{'eventManager'}->registerOne(
        'beforePostfixBuildConfFile',
        sub {
            # Add alias for local root user
            ${ $_[0] } =~ s/^root:.*\n//gim;
            ${ $_[0] } .= 'root: ' . ::setupGetQuestion( 'DEFAULT_ADMIN_ADDRESS' ) . "\n";
        }
    );
    $self->buildConfFile( iMSCP::File->new( filename => $self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'} ), undef, undef, undef, {
        srcname => $dbName,
        create  => TRUE # If the file doesn't exist, create it instead of raising a failure
    } );

    my $rs = execute(
        [ 'postalias', "$self->{'config'}->{'MTA_DB_DEFAULT_TYPE'}:$self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'}" ], \my $stdout, \my $stderr
    );
    debug( $stdout ) if length $stdout;
    !$rs or die( $stderr || 'Unknown error' );
}

=item _buildMainCfFile( )

 Build main.cf file

 Return void, die on failure

=cut

sub _buildMainCfFile
{
    my ( $self ) = @_;

    my $baseServerIp = ::setupGetQuestion( 'BASE_SERVER_IP' );
    my $baseServerIpType = iMSCP::Net->getInstance->getAddrVersion( $baseServerIp );
    my $hostname = ::setupGetQuestion( 'SERVER_HOSTNAME' );
    my $uid = getpwnam( $self->{'config'}->{'MTA_MAILBOX_UID_NAME'} ) or die(
        sprintf( "Couldn't find '%s' user", $self->{'config'}->{'MTA_MAILBOX_UID_NAME'} )
    );
    my $gid = getgrnam( $self->{'config'}->{'MTA_MAILBOX_GID_NAME'} ) or die(
        sprintf( "Couldn't find '%s' group", $self->{'config'}->{'MTA_MAILBOX_GID_NAME'} )
    );

    $self->buildConfFile( 'main.cf', $self->{'config'}->{'MTA_MAIN_CONF_FILE'} );

    # Dynamic parameters
    $self->postconf(
        inet_protocols                   => { values => [ $baseServerIpType ] },
        smtp_bind_address                => { values => [ ( $baseServerIpType eq 'ipv4' && $baseServerIp ne '0.0.0.0' ) ? $baseServerIp : '' ] },
        smtp_bind_address6               => { values => [ ( $baseServerIpType eq 'ipv6' ) ? $baseServerIp : '' ] },
        myhostname                       => { values => [ $hostname ] },
        mydomain                         => { values => [ "$hostname.local" ] },
        myorigin                         => { values => [ '$myhostname' ] },
        smtpd_banner                     => { values => [ "\$myhostname ESMTP i-MSCP $::imscpConfig{'Version'} Managed" ] },
        alias_database                   => { values => [ "$self->{'config'}->{'MTA_DB_DEFAULT_TYPE'}:$self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'}" ] },
        alias_maps                       => { values => [ '$alias_database' ] },
        mail_spool_directory             => { values => [ $self->{'config'}->{'MTA_LOCAL_MAIL_DIR'} ] },
        virtual_mailbox_base             => { values => [ $self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'} ] },
        virtual_minimum_uid              => { values => [ $uid ] },
        virtual_uid_maps                 => { values => [ $uid ] },
        virtual_gid_maps                 => { values => [ $gid ] },
        # Include subdomains for any domain added in the relay_domains table
        # Avoid to add an entry such as .domain.tld for subdomains
        parent_domain_matches_subdomains => { action => 'add', values => [ 'relay_domains' ] },
        # Add TLS parameters if required
        ::setupGetQuestion( 'SERVICES_SSL_ENABLED' ) ne 'yes' ? () : (
            # smtpd TLS parameters (opportunistic)
            smtpd_tls_security_level         => { values => [ 'may' ] },
            smtpd_tls_ciphers                => { values => [ 'high' ] },
            smtpd_tls_exclude_ciphers        => { values => [ 'aNULL', 'MD5' ] },
            smtpd_tls_protocols              => { values => [ '!SSLv2', '!SSLv3' ] },
            smtpd_tls_loglevel               => { values => [ 0 ] },
            smtpd_tls_cert_file              => { values => [ "$::imscpConfig{'CONF_DIR'}/imscp_services.pem" ] },
            smtpd_tls_key_file               => { values => [ "$::imscpConfig{'CONF_DIR'}/imscp_services.pem" ] },
            smtpd_tls_auth_only              => { values => [ 'no' ] },
            smtpd_tls_received_header        => { values => [ 'yes' ] },
            smtpd_tls_session_cache_database => { values => [ 'btree:${data_directory}/smtpd_scache' ] },
            smtpd_tls_session_cache_timeout  => { values => [ '3600s' ] },
            # smtp TLS parameters (opportunistic)
            smtp_tls_security_level          => { values => [ 'may' ] },
            smtp_tls_ciphers                 => { values => [ 'high' ] },
            smtp_tls_exclude_ciphers         => { values => [ 'aNULL', 'MD5' ] },
            smtp_tls_protocols               => { values => [ '!SSLv2', '!SSLv3' ] },
            smtp_tls_loglevel                => { values => [ 0 ] },
            smtp_tls_CAfile                  => { values => [ $::imscpConfig{'DISTRO_CA_BUNDLE'} ] },
            smtp_tls_session_cache_database  => { values => [ 'btree:${data_directory}/smtp_scache' ] },
            smtp_tls_session_cache_timeout   => { values => [ '3600s' ] }
        ),
        # See http://www.postfix.org/COMPATIBILITY_README.html
        version->parse( $self->{'config'}->{'MTA_VERSION'} ) < version->parse( '3.0.0' ) ? () : ( compatibility_level => => { values => [ 2 ] } )
    );
}

=item _buildMasterCfFile( )

 Build master.cf file

 Return void, die on failure

=cut

sub _buildMasterCfFile
{
    my ( $self ) = @_;

    $self->buildConfFile( 'master.cf', $self->{'config'}->{'MTA_MASTER_CONF_FILE'}, undef, {
        ARPL_PATH            => "$::imscpConfig{'BACKEND_ROOT_DIR'}/messenger/imscp-arpl-msgr",
        IMSCP_GROUP          => $::imscpConfig{'IMSCP_GROUP'},
        MTA_MAILBOX_UID_NAME => $self->{'config'}->{'MTA_MAILBOX_UID_NAME'}
    } );
}

=item _removeUser( )

 Remove user

 Return void, die on failure

=cut

sub _removeUser
{
    iMSCP::SystemUser->new( force => 'yes' )->delSystemUser( $_[0]->{'config'}->{'MTA_MAILBOX_UID_NAME'} );
}

=item _removeFiles( )

 Remove files

 Return void, die on failure

=cut

sub _removeFiles
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => $self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'} )->remove();
    iMSCP::File->new( filename => $self->{'config'}->{'MAIL_LOG_CONVERT_PATH'} )->remove();
}

=item _shutdown( )

 See iMSCP::Servers::Abstract::_shutdown()

=cut

sub _shutdown
{
    my ( $self ) = @_;

    while ( my ( $path, $type ) = each( %{ $self->{'_postmap'} } ) ) {
        # We need test for database existence as it can have been removed
        next unless -f $path;
        $self->postmap( $path, $type );
    }

    return unless my $action = $self->{'restart'} ? 'restart' : ( $self->{'reload'} ? 'reload' : undef );

    $self->$action();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
