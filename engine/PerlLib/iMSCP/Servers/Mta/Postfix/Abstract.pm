=head1 NAME

 iMSCP::Servers::Mta::Postfix::Abstract - i-MSCP Postfix server abstract implementation

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

package iMSCP::Servers::Mta::Postfix::Abstract;

use strict;
use warnings;
use autouse Fcntl => qw/ O_RDONLY /;
use autouse 'iMSCP::Rights' => qw/ setRights /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Getopt iMSCP::Net iMSCP::SystemGroup iMSCP::SystemUser /;
use File::Basename;
use File::Temp;
use iMSCP::Config;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute executeNoWait /;
use iMSCP::File;
use Tie::File;
use iMSCP::Service;
use parent 'iMSCP::Servers::Mta';

=head1 DESCRIPTION

 i-MSCP Postfix server abstract implementation.

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 See iMSCP::Servers::Abstract::preinstall()

=cut

sub preinstall
{
    my ($self) = @_;

    $self->SUPER::preinstall();
    $self->_createUserAndGroup();
    $self->_makeDirs();
}

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ($self) = @_;

    $self->_setVersion();
    $self->_configure();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ($self) = @_;

    $self->{'eventManager'}->registerOne(
        'beforeSetupRestartServices',
        sub {
            for ( keys %{$self->{'_postmap'}} ) {
                $self->{'_maps'}->{$_}->mode( 0640 ) if $self->{'_maps'}->{$_};
                $self->postmap( $_ );
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
    my ($self) = @_;

    $self->_removeUser();
    $self->_removeFiles();
}

=item setEnginePermissions( )

 See iMSCP::Servers::Abstract::SetEnginePermissions()

=cut

sub setEnginePermissions
{
    my ($self) = @_;
    # eg. /etc/postfix/main.cf
    setRights( $self->{'config'}->{'MTA_MAIN_CONF_FILE'},
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0644'
        }
    );
    # eg. /etc/postfix/master.cf
    setRights( $self->{'config'}->{'MTA_MASTER_CONF_FILE'},
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0644'
        }
    );
    # eg. /etc/aliases
    setRights( $self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'},
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
            mode  => '0644'
        }
    );
    # eg. /etc/postfix/imscp
    setRights( $self->{'config'}->{'MTA_VIRTUAL_CONF_DIR'},
        {
            user      => $main::imscpConfig{'ROOT_USER'},
            group     => $main::imscpConfig{'ROOT_GROUP'},
            dirmode   => '0750',
            filemode  => '0640',
            recursive => 1
        }
    );
    # eg. /var/www/imscp/engine/messenger
    setRights( "$main::imscpConfig{'ENGINE_ROOT_DIR'}/messenger",
        {
            user      => $main::imscpConfig{'ROOT_USER'},
            group     => $main::imscpConfig{'IMSCP_GROUP'},
            dirmode   => '0750',
            filemode  => '0750',
            recursive => 1
        }
    );
    # eg. /var/mail/virtual
    setRights( $self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'},
        {
            user      => $self->{'config'}->{'MTA_MAILBOX_UID_NAME'},
            group     => $self->{'config'}->{'MTA_MAILBOX_GID_NAME'},
            dirmode   => '0750',
            filemode  => '0640',
            recursive => iMSCP::Getopt->fixPermissions
        }
    );
    # eg. /usr/sbin/maillogconvert.pl
    setRights( $self->{'config'}->{'MAIL_LOG_CONVERT_PATH'},
        {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ROOT_GROUP'},
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

    'Postfix';
}

=item getHumanServerName( )

 See iMSCP::Servers::Abstract::getHumanServerName()

=cut

sub getHumanServerName
{
    my ($self) = @_;

    sprintf( 'Postfix %s', $self->getVersion());
}

=item getVersion( )

 See iMSCP::Servers::Abstract::getVersion()

=cut

sub getVersion
{
    my ($self) = @_;

    $self->{'config'}->{'MTA_VERSION'};
}

=item addDomain( \%moduleData )

 See iMSCP::Servers::Mta::addDomain()

=cut

sub addDomain
{
    my ($self, $moduleData) = @_;

    # Do not list `SERVER_HOSTNAME' in BOTH `mydestination' and `virtual_mailbox_domains'
    return if $moduleData->{'DOMAIN_NAME'} eq $main::imscpConfig{'SERVER_HOSTNAME'};

    $self->{'eventManager'}->trigger( 'beforePostfixAddDomain', $moduleData );
    $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_DMN_HASH'}, qr/\Q$moduleData->{'DOMAIN_NAME'}\E\s+[^\n]*/ );
    $self->deleteMapEntry( $self->{'config'}->{'MTA_RELAY_HASH'}, qr/\Q$moduleData->{'DOMAIN_NAME'}\E\s+[^\n]*/ );

    if ( $moduleData->{'MAIL_ENABLED'} ) { # Mail is managed by this server
        $self->addMapEntry( $self->{'config'}->{'MTA_VIRTUAL_DMN_HASH'}, "$moduleData->{'DOMAIN_NAME'}\tOK" );
    } elsif ( $moduleData->{'EXTERNAL_MAIL'} eq 'on' ) { # Mail is managed by external server
        $self->addMapEntry( $self->{'config'}->{'MTA_RELAY_HASH'}, "$moduleData->{'DOMAIN_NAME'}\tOK" );
    }

    $self->{'eventManager'}->trigger( 'afterPostfixAddDomain', $moduleData );
}

=item disableDomain( \%moduleData )

 See iMSCP::Servers::Mta::disableDomain()

=cut

sub disableDomain
{
    my ($self, $moduleData) = @_;

    return if $moduleData->{'DOMAIN_NAME'} eq $main::imscpConfig{'SERVER_HOSTNAME'};

    $self->{'eventManager'}->trigger( 'beforePostfixDisableDomain', $moduleData );
    $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_DMN_HASH'}, qr/\Q$moduleData->{'DOMAIN_NAME'}\E\s+[^\n]*/ );
    $self->deleteMapEntry( $self->{'config'}->{'MTA_RELAY_HASH'}, qr/\Q$moduleData->{'DOMAIN_NAME'}\E\s+[^\n]*/ );
    $self->{'eventManager'}->trigger( 'afterPostfixDisableDomain', $moduleData );
}

=item deleteDomain( \%moduleData )

 See iMSCP::Servers::Mta::deleteDomain()

=cut

sub deleteDomain
{
    my ($self, $moduleData) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixDeleteDomain', $moduleData );
    $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_DMN_HASH'}, qr/\Q$moduleData->{'DOMAIN_NAME'}\E\s+[^\n]*/ );
    $self->deleteMapEntry( $self->{'config'}->{'MTA_RELAY_HASH'}, qr/\Q$moduleData->{'DOMAIN_NAME'}\E\s+[^\n]*/ );
    iMSCP::Dir->new( dirname => "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}" )->remove();
    $self->{'eventManager'}->trigger( 'afterPostfixDeleteDomain', $moduleData );
}

=item addSubdomain( \%moduleData )

 See iMSCP::Servers::Mta::addSubdomain()

=cut

sub addSubdomain
{
    my ($self, $moduleData) = @_;

    # Do not list `SERVER_HOSTNAME' in BOTH `mydestination' and `virtual_mailbox_domains'
    return if $moduleData->{'DOMAIN_NAME'} eq $main::imscpConfig{'SERVER_HOSTNAME'};

    $self->{'eventManager'}->trigger( 'beforePostfixAddSubdomain', $moduleData );
    $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_DMN_HASH'}, qr/\Q$moduleData->{'DOMAIN_NAME'}\E\s+[^\n]*/ );
    $self->addMapEntry( $self->{'config'}->{'MTA_VIRTUAL_DMN_HASH'}, "$moduleData->{'DOMAIN_NAME'}\tOK" ) if $moduleData->{'MAIL_ENABLED'};
    $self->{'eventManager'}->trigger( 'afterPostfixAddSubdomain', $moduleData );
}

=item disableSubdomain( \%moduleData )

 See iMSCP::Servers::Mta::disableSubdomain()

=cut

sub disableSubdomain
{
    my ($self, $moduleData) = @_;

    return if $moduleData->{'DOMAIN_NAME'} eq $main::imscpConfig{'SERVER_HOSTNAME'};

    $self->{'eventManager'}->trigger( 'beforePostfixDisableSubdomain', $moduleData );
    $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_DMN_HASH'}, qr/\Q$moduleData->{'DOMAIN_NAME'}\E\s+[^\n]*/ );
    $self->{'eventManager'}->trigger( 'afterPostfixDisableSubdomain', $moduleData );
}

=item deleteSubdomain( \%moduleData )

 See iMSCP::Servers::Mta::deleteSubdomain()

=cut

sub deleteSubdomain
{
    my ($self, $moduleData) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixDeleteSubdomain', $moduleData );
    $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_DMN_HASH'}, qr/\Q$moduleData->{'DOMAIN_NAME'}\E\s+[^\n]*/ );
    iMSCP::Dir->new( dirname => "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}" )->remove();
    $self->{'eventManager'}->trigger( 'afterPostfixDeleteSubdomain', $moduleData );
}

=item addMail( \%moduleData )

 See iMSCP::Servers::Mta::addMail()

=cut

sub addMail
{
    my ($self, $moduleData) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixAddMail', $moduleData );

    if ( $moduleData->{'MAIL_CATCHALL'} ) {
        $self->addMapEntry( $self->{'config'}->{'MTA_VIRTUAL_ALIAS_HASH'}, "$moduleData->{'MAIL_ADDR'}\t$moduleData->{'MAIL_CATCHALL'}" );
    } else {
        my $isMailAcc = index( $moduleData->{'MAIL_TYPE'}, '_mail' ) != -1 && $moduleData->{'DOMAIN_NAME'} ne $main::imscpConfig{'SERVER_HOSTNAME'};
        my $isForwardAccount = index( $moduleData->{'MAIL_TYPE'}, '_forward' ) != -1;
        return unless $isMailAcc || $isForwardAccount;

        $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_MAILBOX_HASH'}, qr/\Q$moduleData->{'MAIL_ADDR'}\E\s+[^\n]*/ );
        $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_ALIAS_HASH'}, qr/\Q$moduleData->{'MAIL_ADDR'}\E\s+[^\n]*/ );

        my $responderEntry = "moduleDatadata->{'MAIL_ACC'}\@imscp-arpl.$moduleData->{'DOMAIN_NAME'}";
        $self->deleteMapEntry( $self->{'config'}->{'MTA_TRANSPORT_HASH'}, qr/\Q$responderEntry\E\s+[^\n]*/ );

        if ( $isMailAcc ) {
            my $maildir = "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}";

            # Create mailbox
            for ( $moduleData->{'DOMAIN_NAME'}, "$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}" ) {
                iMSCP::Dir->new( dirname => "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$_" )->make( {
                    user           => $self->{'config'}->{'MTA_MAILBOX_UID_NAME'},
                    group          => $self->{'config'}->{'MTA_MAILBOX_GID_NAME'},
                    mode           => 0750,
                    fixpermissions => iMSCP::Getopt->fixPermissions
                } );
            }
            for ( qw/ cur new tmp / ) {
                iMSCP::Dir->new( dirname => "$maildir/$_" )->make( {
                    user           => $self->{'config'}->{'MTA_MAILBOX_UID_NAME'},
                    group          => $self->{'config'}->{'MTA_MAILBOX_GID_NAME'},
                    mode           => 0750,
                    fixpermissions => iMSCP::Getopt->fixPermissions
                } );
            }

            # Add virtual mailbox map entry
            $self->addMapEntry(
                $self->{'config'}->{'MTA_VIRTUAL_MAILBOX_HASH'}, "$moduleData->{'MAIL_ADDR'}\t$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}/"
            );
        } else {
            iMSCP::Dir->new(
                dirname => "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}"
            )->remove();
        }

        # Add virtual alias map entry
        $self->addMapEntry(
            $self->{'config'}->{'MTA_VIRTUAL_ALIAS_HASH'},
            $moduleData->{'MAIL_ADDR'} # Recipient
                . "\t" # Separator
                . join ',', (
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
                    ( $moduleData->{'MAIL_HAS_AUTO_RESPONDER'} ? $responderEntry : () )
                )
        );

        # Add transport map entry for autoresponder if needed
        $self->addMapEntry( $self->{'config'}->{'MTA_TRANSPORT_HASH'}, "$responderEntry\timscp-arpl:" ) if $moduleData->{'MAIL_HAS_AUTO_RESPONDER'};

    }

    $self->{'eventManager'}->trigger( 'afterPostfixAddMail', $moduleData );
}

=item disableMail( \%moduleData )

 See iMSCP::Servers::Mta::disableMail()

=cut

sub disableMail
{
    my ($self, $moduleData) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixDisableMail', $moduleData );

    if ( $moduleData->{'MAIL_CATCHALL'} ) {
        $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_ALIAS_HASH'}, qr/\Q$moduleData->{'MAIL_ADDR'}\E\s+\Q$moduleData->{'MAIL_CATCHALL'}/ );
    } else {
        $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_MAILBOX_HASH'}, qr/\Q$moduleData->{'MAIL_ADDR'}\E\s+[^\n]*/ );
        $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_ALIAS_HASH'}, qr/\Q$moduleData->{'MAIL_ADDR'}\E\s+[^\n]*/ );

        my $responderEntry = "$moduleData->{'MAIL_ACC'}\@imscp-arpl.$moduleData->{'DOMAIN_NAME'}";
        $self->deleteMapEntry( $self->{'config'}->{'MTA_TRANSPORT_HASH'}, qr/\Q$responderEntry\E\s+[^\n]*/ );
    }

    $self->{'eventManager'}->trigger( 'afterPostfixDisableMail', $moduleData );
}

=item deleteMail( \%moduleData )

 See iMSCP::Servers::Mta::deleteMail()

=cut

sub deleteMail
{
    my ($self, $moduleData) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixDeleteMail', $moduleData );

    if ( $moduleData->{'MAIL_CATCHALL'} ) {
        $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_ALIAS_HASH'}, qr/\Q$moduleData->{'MAIL_ADDR'}\E\s+\Q$moduleData->{'MAIL_CATCHALL'}/ );
    } else {
        $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_MAILBOX_HASH'}, qr/\Q$moduleData->{'MAIL_ADDR'}\E\s+[^\n]*/ );
        $self->deleteMapEntry( $self->{'config'}->{'MTA_VIRTUAL_ALIAS_HASH'}, qr/\Q$moduleData->{'MAIL_ADDR'}\E\s+[^\n]*/ );;

        my $responderEntry = "$moduleData->{'MAIL_ACC'}\@imscp-arpl.$moduleData->{'DOMAIN_NAME'}";
        $self->deleteMapEntry( $self->{'config'}->{'MTA_TRANSPORT_HASH'}, qr/\Q$responderEntry\E\s+[^\n]*/ );

        iMSCP::Dir->new( dirname => "$self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}/$moduleData->{'DOMAIN_NAME'}/$moduleData->{'MAIL_ACC'}" )->remove();
    }

    $self->{'eventManager'}->trigger( 'afterPostfixDeleteMail', $moduleData );
}

=item getTraffic( \%trafficDb [, $logFile, \%trafficIndexDb ] )

 See iMSCP::Servers::Mta::getTraffic()

=cut

sub getTraffic
{
    my ($self, $trafficDb, $logFile, $trafficIndexDb) = @_;
    $logFile ||= "$main::imscpConfig{'TRAFF_LOG_DIR'}/$main::imscpConfig{'MAIL_TRAFF_LOG'}";

    unless ( -f $logFile ) {
        debug( sprintf( "SMTP %s log file doesn't exist. Skipping...", $logFile ));
        return;
    }

    debug( sprintf( 'Processing SMTP %s log file', $logFile ));

    # We use an index database to keep trace of the last processed logs
    $trafficIndexDb or die %{$trafficIndexDb}, 'iMSCP::Config', fileName => "$main::imscpConfig{'IMSCP_HOMEDIR'}/traffic_index.db", nocroak => 1;
    my ($idx, $idxContent) = ( $trafficIndexDb->{'smtp_lineNo'} || 0, $trafficIndexDb->{'smtp_lineContent'} );

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
    } elsif ( $idxContent ne '' && substr( $logFile, -2 ) ne '.1' ) {
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

=item addMapEntry( $mapPath [, $entry ] )

 Add the given entry into the given Postfix map

 Without any $entry passed-in, the map will be simply created.

 Param string $mapPath Map file path
 Param string $entry OPTIONAL Map entry to add
 Return void, die on failure

=cut

sub addMapEntry
{
    my ($self, $mapPath, $entry) = @_;

    my $file = $self->_getMapFileObject( $mapPath );

    return unless defined $entry;

    my $mapFileContentRef = $file->getAsRef();
    ${$mapFileContentRef} =~ s/^\Q$entry\E\n//gim;
    ${$mapFileContentRef} .= "$entry\n";
    $file->save();
    $self->{'_postmap'}->{$mapPath} ||= 1;
}

=item deleteMapEntry( $mapPath, $entry )

 Delete the given entry from the given Postfix map

 Param string $mapPath Map file path
 Param Regexp $entry Regexp matching map entry to delete
 Return void, die on failure

=cut

sub deleteMapEntry
{
    my ($self, $mapPath, $entry) = @_;

    my $file = $self->_getMapFileObject( $mapPath );
    my $mapFileContentRef = $file->getAsRef();

    return unless ${$mapFileContentRef} =~ s/^$entry\n//gim;

    $file->save();
    $self->{'_postmap'}->{$mapPath} ||= 1;
}

=item postmap( $mapPath [, $mapType = 'hash' ] )

 Postmap the given map

 Param string $mapPath Map path
 Param string $hashtype Map type (default: hash)
 Return void, die on failure

=cut

sub postmap
{
    my (undef, $mapPath, $mapType) = @_;
    $mapType ||= 'hash';

    my $rs = execute( "postmap $mapType:$mapPath", \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die ( $stderr || 'Unknown error' );
}

=item postconf( $conffile, %params )

 Provides an interface to POSTCONF(1) for editing parameters in Postfix main.cf configuration file

 Param hash %params A hash where each key is a Postfix parameter name and the value, a hashes describing in order:
  - action : Action to be performed (add|replace|remove) -- Default add
  - values : An array containing parameter value(s) to add, replace or remove. For values to be removed, both strings and Regexp are supported.
  - empty  : OPTIONAL Flag that allows to force adding of empty parameter
  - before : OPTIONAL Option that allows to add values before the given value (expressed as a Regexp)
  - after  : OPTIONAL Option that allows to add values after the given value (expressed as a Regexp)

  `replace' action versus `remove' action
    The `replace' action replace the full value of the given parameter while the `remove' action only remove the specified value portion in the
    parameter value. Note that when the resulting value is an empty value, the paramerter is removed from the configuration file unless the `empty'
    flag has been specified.

  `before' and `after' options:
    The `before' and `after' options are only relevant for the `add' action. Note also that the `before' option has a highter precedence than the
    `after' option.
  
  Unknown postfix parameters
    Unknown Postfix parameter are silently ignored

  Usage example:

    Adding parameters

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
 
    Removing parameters

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
    my ($self, %params) = @_;

    %params or croak( 'Missing parameters ' );

    my @pToDel = ();
    my $conffile = $self->{'config'}->{'MTA_CONF_DIR'} || '/etc/postfix';
    my $time = time();

    # Avoid POSTCONF(1) being slow by waiting 2 seconds before next processing
    # See https://groups.google.com/forum/#!topic/list.postfix.users/MkhEqTR6yRM
    utime $time, $time-2, $self->{'config'}->{'MTA_MAIN_CONF_FILE'} or die(
        sprintf( "Couldn't touch %s file: %s", $self->{'config'}->{'MTA_MAIN_CONF_FILE'} )
    );

    my ($stdout, $stderr);
    executeNoWait(
        [ 'postconf', '-c', $conffile, keys %params ],
        sub {
            return unless ( my $p, my $v ) = $_[0] =~ /^([^=]+)\s+=\s*(.*)/;

            my (@vls, @rpls) = ( split( /,\s*/, $v ), () );

            defined $params{$p}->{'values'} && ref $params{$p}->{'values'} eq 'ARRAY' or croak(
                sprintf( "Missing or invalid `values' for the %s parameter. Expects an array of values", $p )
            );

            for $v( @{$params{$p}->{'values'}} ) {
                if ( !$params{$p}->{'action'} || $params{$p}->{'action'} eq 'add' ) {
                    unless ( $params{$p}->{'before'} || $params{$p}->{'after'} ) {
                        next if grep( $_ eq $v, @vls );
                        push @vls, $v;
                        next;
                    }

                    # If the parameter already exists, we delete it as someone could want move it
                    @vls = grep( $_ ne $v, @vls );
                    my $regexp = $params{$p}->{'before'} || $params{$p}->{'after'};
                    ref $regexp eq 'Regexp' or croak( 'Invalid before|after option. Expects a Regexp' );
                    my ($idx) = grep ( $vls[$_] =~ /^$regexp$/, 0 .. ( @vls-1 ) );
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
            $params{$p} = join ', ', @rpls ? @rpls : @vls;

            unless ( $forceEmpty || $params{$p} ne '' ) {
                push @pToDel, $p;
                delete $params{$p};
            }
        },
        sub { $stderr .= shift }
    ) == 0 or die( $stderr || 'Unknown error' );

    if ( %params ) {
        my $cmd = [ 'postconf', '-e', '-c', $conffile ];
        while ( my ($param, $value) = each %params ) { push @{$cmd}, "$param=$value" };
        execute( $cmd, \$stdout, \$stderr ) == 0 or die( $stderr || 'Unknown error' );
        debug( $stdout ) if $stdout;
    }

    if ( @pToDel ) {
        execute( [ 'postconf', '-X', '-c', $conffile, @pToDel ], \$stdout, \$stderr ) == 0 or die( $stderr || 'Unknown error' );
        debug( $stdout ) if $stdout;
    };

    $self->{'reload'} ||= 1;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 See iMSCP::Servers::Mta::_init()

=cut

sub _init
{
    my ($self) = @_;

    ref $self ne __PACKAGE__ or croak( sprintf( 'The %s class is an abstract class which cannot be instantiated', __PACKAGE__ ));

    @{$self}{qw/ restart reload cfgDir /} = ( 0, 0, "$main::imscpConfig{'CONF_DIR'}/postfix" );
    $self->SUPER::_init();
}

=item _getMapFileObject( mapPath )

 Get iMSCP::File object for the given postfix map

 Param string $mapPath Postfix map path
 Return iMSCP::File, die on failure

=cut

sub _getMapFileObject
{
    my ($self, $mapPath) = @_;

    $self->{'_maps'}->{$mapPath} ||= do {
        my $file = iMSCP::File->new( filename => $mapPath );

        unless ( -f $mapPath ) {
            $file->set( <<"EOF"
# Postfix @{ [ basename( $mapPath ) ] } map - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN

EOF
            )->save()->mode( 0640 );
            $self->{'_postmap'}->{$mapPath} ||= 1;
        }

        $file;
    }
}

=item _createUserAndGroup( )

 Create vmail user and mail group

 Return void, die on failure

=cut

sub _createUserAndGroup
{
    my ($self) = @_;

    iMSCP::SystemGroup->getInstance()->addSystemGroup( $self->{'config'}->{'MTA_MAILBOX_GID_NAME'}, 1 );

    my $systemUser = iMSCP::SystemUser->new(
        username => $self->{'config'}->{'MTA_MAILBOX_UID_NAME'},
        group    => $self->{'config'}->{'MTA_MAILBOX_GID_NAME'},
        comment  => 'vmail user',
        home     => $self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'},
        system   => 1
    );
    $systemUser->addSystemUser();
    $systemUser->addToGroup( $main::imscpConfig{'IMSCP_GROUP'} );
}

=item _makeDirs( )

 Create directories

 Return void, die on failure

=cut

sub _makeDirs
{
    my ($self) = @_;

    my @directories = (
        [
            $self->{'config'}->{'MTA_VIRTUAL_CONF_DIR'}, # eg. /etc/postfix/imscp
            $main::imscpConfig{'ROOT_USER'},
            $main::imscpConfig{'ROOT_GROUP'},
            0750
        ],
        [
            $self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'}, # eg. /var/mail/virtual
            $self->{'config'}->{'MTA_MAILBOX_UID_NAME'},
            $self->{'config'}->{'MTA_MAILBOX_GID_NAME'},
            0750
        ]
    );

    # Make sure to start with clean directory
    iMSCP::Dir->new( dirname => $self->{'config'}->{'MTA_VIRTUAL_CONF_DIR'} )->remove();

    for ( @directories ) {
        iMSCP::Dir->new( dirname => $_->[0] )->make( {
            user           => $_->[1],
            group          => $_->[2],
            mode           => $_->[3],
            fixpermissions => iMSCP::Getopt->fixPermissions
        } );
    }
}

=item _configure( )

 Configure Postfix

 Return void, die on failure

=cut

sub _configure
{
    my ($self) = @_;

    $self->{'eventManager'}->trigger( 'beforePostfixConfigure' );
    $self->_createMaps();
    $self->_buildAliasesDb();
    $self->_buildMainCfFile();
    $self->_buildMasterCfFile();
    $self->{'eventManager'}->trigger( 'afterPostixConfigure' );
}

=item _setVersion( )

 Set Postfix version

 Return void, die on failure

=cut

sub _setVersion
{
    my ($self) = @_;

    my $rs = execute( [ 'postconf', '-d', '-h', 'mail_version' ], \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );
    $stdout =~ /^([\d.]+)/ or die( "Couldn't guess Postfix version from the `postconf -d -h mail_version` command output" );
    $self->{'config'}->{'MTA_VERSION'} = $1;
    debug( sprintf( 'Postfix version set to: %s', $stdout ));
}

=item _createMaps( )

 Ceate maps

 Return void, die on failure

=cut

sub _createMaps
{
    my ($self) = @_;

    $self->addMapEntry( $_ ) for $self->{'config'}->{'MTA_VIRTUAL_ALIAS_HASH'}, $self->{'config'}->{'MTA_VIRTUAL_DMN_HASH'},
        $self->{'config'}->{'MTA_VIRTUAL_MAILBOX_HASH'}, $self->{'config'}->{'MTA_TRANSPORT_HASH'}, $self->{'config'}->{'MTA_RELAY_HASH'};
}

=item _buildAliasesDb( )

 Build aliases database

 Return void, die on failure

=cut

sub _buildAliasesDb
{
    my ($self) = @_;

    $self->{'eventManager'}->registerOne(
        'beforePostfixBuildConfFile',
        sub {
            # Add alias for local root user
            ${$_[0]} =~ s/^root:.*\n//gim;
            ${$_[0]} .= 'root: ' . main::setupGetQuestion( 'DEFAULT_ADMIN_ADDRESS' ) . "\n";
        }
    );
    $self->buildConfFile(
        ( -f $self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'} ? $self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'} : File::Temp->new() ),
        $self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'}, undef, undef, { srcname => basename( $self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'} ) }
    );

    my $rs = execute( 'newaliases', \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );
}

=item _buildMainCfFile( )

 Build main.cf file

 Return void, die on failure

=cut

sub _buildMainCfFile
{
    my ($self) = @_;

    my $baseServerIp = main::setupGetQuestion( 'BASE_SERVER_IP' );
    my $baseServerIpType = iMSCP::Net->getInstance->getAddrVersion( $baseServerIp );
    my $gid = getgrnam( $self->{'config'}->{'MTA_MAILBOX_GID_NAME'} );
    my $uid = getpwnam( $self->{'config'}->{'MTA_MAILBOX_UID_NAME'} );
    my $hostname = main::setupGetQuestion( 'SERVER_HOSTNAME' );

    $self->buildConfFile( 'main.cf', $self->{'config'}->{'MTA_MAIN_CONF_FILE'}, undef,
        {
            MTA_INET_PROTOCOLS       => $baseServerIpType,
            MTA_SMTP_BIND_ADDRESS    => ( $baseServerIpType eq 'ipv4' && $baseServerIp ne '0.0.0.0' ) ? $baseServerIp : '',
            MTA_SMTP_BIND_ADDRESS6   => ( $baseServerIpType eq 'ipv6' ) ? $baseServerIp : '',
            MTA_HOSTNAME             => $hostname,
            MTA_LOCAL_DOMAIN         => "$hostname.local",
            MTA_VERSION              => $main::imscpConfig{'Version'}, # Fake data expected
            MTA_TRANSPORT_HASH       => $self->{'config'}->{'MTA_TRANSPORT_HASH'},
            MTA_LOCAL_MAIL_DIR       => $self->{'config'}->{'MTA_LOCAL_MAIL_DIR'},
            MTA_LOCAL_ALIAS_HASH     => $self->{'config'}->{'MTA_LOCAL_ALIAS_HASH'},
            MTA_VIRTUAL_MAIL_DIR     => $self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'},
            MTA_VIRTUAL_DMN_HASH     => $self->{'config'}->{'MTA_VIRTUAL_DMN_HASH'},
            MTA_VIRTUAL_MAILBOX_HASH => $self->{'config'}->{'MTA_VIRTUAL_MAILBOX_HASH'},
            MTA_VIRTUAL_ALIAS_HASH   => $self->{'config'}->{'MTA_VIRTUAL_ALIAS_HASH'},
            MTA_RELAY_HASH           => $self->{'config'}->{'MTA_RELAY_HASH'},
            MTA_MAILBOX_MIN_UID      => $uid,
            MTA_MAILBOX_UID          => $uid,
            MTA_MAILBOX_GID          => $gid
        }
    );

    # Add TLS parameters if required
    return unless main::setupGetQuestion( 'SERVICES_SSL_ENABLED' ) eq 'yes';

    $self->{'eventManager'}->register(
        'afterPostixConfigure',
        sub {
            my %params = (
                # smtpd TLS parameters (opportunistic)
                smtpd_tls_security_level         => {
                    action => 'replace',
                    values => [ 'may' ]
                },
                smtpd_tls_ciphers                => {
                    action => 'replace',
                    values => [ 'high' ]
                },
                smtpd_tls_exclude_ciphers        => {
                    action => 'replace',
                    values => [ 'aNULL', 'MD5' ]
                },
                smtpd_tls_protocols              => {
                    action => 'replace',
                    values => [ '!SSLv2', '!SSLv3' ]
                },
                smtpd_tls_loglevel               => {
                    action => 'replace',
                    values => [ '0' ]
                },
                smtpd_tls_cert_file              => {
                    action => 'replace',
                    values => [ "$main::imscpConfig{'CONF_DIR'}/imscp_services.pem" ]
                },
                smtpd_tls_key_file               => {
                    action => 'replace',
                    values => [ "$main::imscpConfig{'CONF_DIR'}/imscp_services.pem" ]
                },
                smtpd_tls_auth_only              => {
                    action => 'replace',
                    values => [ 'no' ]
                },
                smtpd_tls_received_header        => {
                    action => 'replace',
                    values => [ 'yes' ]
                },
                smtpd_tls_session_cache_database => {
                    action => 'replace',
                    values => [ 'btree:/var/lib/postfix/smtpd_scache' ]
                },
                smtpd_tls_session_cache_timeout  => {
                    action => 'replace',
                    values => [ '3600s' ]
                },
                # smtp TLS parameters (opportunistic)
                smtp_tls_security_level          => {
                    action => 'replace',
                    values => [ 'may' ]
                },
                smtp_tls_ciphers                 => {
                    action => 'replace',
                    values => [ 'high' ]
                },
                smtp_tls_exclude_ciphers         => {
                    action => 'replace',
                    values => [ 'aNULL', 'MD5' ]
                },
                smtp_tls_protocols               => {
                    action => 'replace',
                    values => [ '!SSLv2', '!SSLv3' ]
                },
                smtp_tls_loglevel                => {
                    action => 'replace',
                    values => [ '0' ]
                },
                smtp_tls_CAfile                  => {
                    action => 'replace',
                    values => [ '/etc/ssl/certs/ca-certificates.crt' ]
                },
                smtp_tls_session_cache_database  => {
                    action => 'replace',
                    values => [ 'btree:/var/lib/postfix/smtp_scache' ]
                }
            );

            if ( version->parse( $self->{'config'}->{'MTA_VERSION'} ) >= version->parse( '2.10.0' ) ) {
                $params{'smtpd_relay_restrictions'} = {
                    action => 'replace',
                    values => [ '' ],
                    empty  => 1
                };
            }

            if ( version->parse( $self->{'config'}->{'MTA_VERSION'} ) >= version->parse( '3.0.0' ) ) {
                $params{'compatibility_level'} = {
                    action => 'replace',
                    values => [ '2' ]
                };
            }

            $self->postconf( %params );
        }
    );
}

=item _buildMasterCfFile( )

 Build master.cf file

 Return void, die on failure

=cut

sub _buildMasterCfFile
{
    my ($self) = @_;

    $self->buildConfFile( 'master.cf', $self->{'config'}->{'MTA_MASTER_CONF_FILE'}, undef,
        {
            ARPL_PATH            => "$main::imscpConfig{'ROOT_DIR'}/engine/messenger/imscp-arpl-msgr",
            IMSCP_GROUP          => $main::imscpConfig{'IMSCP_GROUP'},
            MTA_MAILBOX_UID_NAME => $self->{'config'}->{'MTA_MAILBOX_UID_NAME'}
        }
    );
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
    my ($self) = @_;

    iMSCP::Dir->new( dirname => $_ )->remove() for $self->{'config'}->{'MTA_VIRTUAL_CONF_DIR'}, $self->{'config'}->{'MTA_VIRTUAL_MAIL_DIR'};
    iMSCP::File->new( filename => $self->{'config'}->{'MAIL_LOG_CONVERT_PATH'} )->remove();
}

=item _shutdown( $priority )

 See iMSCP::Servers::Abstract::_shutdown()

=cut

sub _shutdown
{
    my ($self, $priority) = @_;

    return unless my $action = $self->{'restart'} ? 'restart' : ( $self->{'reload'} ? 'reload' : undef );

    iMSCP::Service->getInstance()->registerDelayedAction( 'postfix', [ $action, sub { $self->$action(); } ], $priority );
}

=item END

 Regenerate Postfix maps

=cut

END
    {
        return if $? || iMSCP::Getopt->context() eq 'installer';

        return unless my $instance = __PACKAGE__->hasInstance();

        my ($ret, $rs) = ( 0, 0 );

        for ( keys %{$instance->{'_postmap'}} ) {
            if ( $instance->{'_maps'}->{$_} ) {
                $rs = $instance->{'_maps'}->{$_}->mode( 0640 );
                $ret ||= $rs;
                next if $rs;
            }

            $rs = $instance->postmap( $_ );
            $ret ||= $rs;
        }

        $? ||= $ret;
    }

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
