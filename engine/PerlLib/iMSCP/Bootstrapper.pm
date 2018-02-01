=head1 NAME

 iMSCP::Bootstrapper - i-MSCP Bootstrapper

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

package iMSCP::Bootstrapper;

use strict;
use warnings;
use autouse 'Data::Dumper' => qw/ Dumper /;
use autouse 'iMSCP::Crypt' => qw/ decryptRijndaelCBC randomStr /;
use Carp qw/ croak /;
use Class::Autouse qw/ :nostat iMSCP::Database iMSCP::Requirements /;
use File::Spec;
use iMSCP::Debug qw/ debug getMessageByType /;
use iMSCP::Config;
use iMSCP::EventManager;
use iMSCP::Getopt;
use iMSCP::LockFile;
use iMSCP::Umask;
use POSIX qw / tzset /;
# Make sure that object destructors are called on HUP, PIPE, INT and TERM signals
use sigtrap qw/ die normal-signals /;
use parent 'iMSCP::Common::Singleton';

umask 0022;

$ENV{'HOME'} = ( getpwuid $> )[7] or die( "Couldn't find running user homedir" );

=head1 DESCRIPTION

 Bootstrap class for i-MSCP

=head1 PUBLIC METHODS

=over 4

=item boot( \%$options )

 Boot i-MSCP

 Param hashref \%options Bootstrap options
 Return iMSCP::Bootstrapper, die on failure

=cut

sub boot
{
    my ($self, $options) = @_;

    debug( sprintf( 'Booting %s...', iMSCP::Getopt->context()));

    $self->loadMainConfig( $options );

    iMSCP::Getopt->debug( 1 ) if $main::imscpConfig{'DEBUG'};

    $self->lock() unless $options->{'nolock'};

    # Set timezone unless we are in setup or uninstaller execution context (needed to show current local timezone in setup dialog)
    unless ( iMSCP::Getopt->context() =~ /^(?:un)?installer$/ ) {
        $ENV{'TZ'} = $main::imscpConfig{'TIMEZONE'} || 'UTC';
        tzset;
    }

    unless ( $options->{'norequirements'} ) {
        if ( iMSCP::Getopt->context() eq 'installer' ) {
            iMSCP::Requirements->new()->all();
        } else {
            iMSCP::Requirements->new()->user();
        }
    }

    $self->_genKeys() unless $options->{'nokeys'};
    $self->_setDbSettings() unless $options->{'nodatabase'};

    iMSCP::EventManager->getInstance()->trigger( 'onBoot', iMSCP::Getopt->context());
    $self;
}

=item loadMainConfig( \%options )

 Load main configuration file using given options

 Param hashref \%options Options for iMSCP::Config object
 Return void, die on failure

=cut

sub loadMainConfig
{
    my (undef, $options) = @_;

    debug( sprintf( 'Loading i-MSCP master configuration...' ));

    untie %main::imscpConfig;
    tie %main::imscpConfig,
        'iMSCP::Config',
        fileName    => '/etc/imscp/imscp.conf',
        nocreate    => $options->{'nocreate'} // 1,
        nodeferring => $options->{'nodeferring'} // 0,
        nocroak     => $options->{'nocroak'} // 0,
        readonly    => $options->{'config_readonly'} // 0,
        temporary   => $options->{'config_temporary'} // 0;
}

=item lock( [ $lockFile = $main::imscpConfig{'LOCK_DIR'}/imscp.lock [, $nowait = FALSE ] ] )

 Lock a file

 Param bool $nowait OPTIONAL Whether or not to wait for lock
 Return int 1 if lock file has been acquired, 0 if lock file has not been acquired (nowait case), die on failure

=cut

sub lock
{
    my ($self, $lockFile, $nowait) = @_;
    $lockFile = File::Spec->canonpath( $lockFile ||= "$main::imscpConfig{'LOCK_DIR'}/imscp.lock" );

    return 1 if exists $self->{'locks'}->{$lockFile};

    my $lock = iMSCP::LockFile->new( path => $lockFile, non_blocking => $nowait );
    my $ret = $lock->acquire();
    $self->{'locks'}->{$lockFile} = $lock if $ret;
    $ret;
}

=item unlock( [ $lockFile = "$main::imscpConfig{'LOCK_DIR'}/imscp.lock" ] )

 Unlock file

 Param string $lockFile OPTIONAL Lock file path
 Return self

=cut

sub unlock
{
    my ($self, $lockFile) = @_;
    $lockFile = File::Spec->canonpath( $lockFile ||= "$main::imscpConfig{'LOCK_DIR'}/imscp.lock" );

    return $self unless exists $self->{'locks'}->{$lockFile};

    $self->{'locks'}->{$lockFile}->release();
    delete $self->{'locks'}->{$lockFile};
    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _genKeys( )

 Generates encryption key and initialization vector

 Return void, die on failure

=cut

sub _genKeys
{
    $main::imscpKEY = '{KEY}';
    $main::imscpIV = '{IV}';

    eval { require "$main::imscpConfig{'CONF_DIR'}/imscp-db-keys.pl"; };

    if ( $@
        || $main::imscpKEY eq '{KEY}' || length( $main::imscpKEY ) != 32
        || $main::imscpIV eq '{IV}' || length( $main::imscpIV ) != 16
        || ( iMSCP::Getopt->context() eq 'installer' && !-f "$main::imscpConfig{'CONF_DIR'}/imscp-db-keys.php" )
    ) {
        debug( 'Missing or invalid i-MSCP key files. Generating a new key files...' );
        -d $main::imscpConfig{'CONF_DIR'} or die( sprintf( "%s doesn't exist or is not a directory", $main::imscpConfig{'CONF_DIR'} ));

        require Data::Dumper;

        local $UMASK = 0027;
        local $Data::Dumper::Indent = 0;

        ( $main::imscpKEY, $main::imscpIV ) = ( randomStr( 32 ), randomStr( 16 ) );

        for ( qw/ imscp-db-keys.pl imscp-db-keys.php / ) {
            open my $fh, '>', "$main::imscpConfig{'CONF_DIR'}/$_" or die(
                sprintf( "Couldn't open %s file for writing: %s", "$main::imscpConfig{'CONF_DIR'}/$_", $! )
            );
            print $fh <<"EOF";
@{ [ $_ eq 'imscp-db-keys.php' ? '<?php' : "#/usr/bin/perl\n" ]}
# i-MSCP key file @{ [ $_ eq 'imscp-db-keys.php' ? '(FrontEnd)' : '(Backend)' ]} - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
#
# This file must be kept secret !!!

@{ [ Data::Dumper->Dump( [ $main::imscpKEY ], [ $_ eq 'imscp-db-keys.php' ? 'imscpKEY' : 'main::imscpKEY' ] ) ] }
@{ [ Data::Dumper->Dump( [ $main::imscpIV ], [ $_ eq 'imscp-db-keys.php' ? 'imscpIV' : 'main::imscpIV' ] ) ] }

@{[ $_ eq 'imscp-db-keys.php' ? '?>' : "1;\n__END__"]}
EOF
            $fh->close();
        }
    }
}

=item _setDbSettings( )

 Set database connection settings

 Return void, die on failure

=cut

sub _setDbSettings
{
    my $db = iMSCP::Database->getInstance();
    $db->set( $_, $main::imscpConfig{$_} ) for qw/ DATABASE_HOST DATABASE_PORT DATABASE_NAME DATABASE_USER /;
    $db->set( 'DATABASE_PASSWORD', decryptRijndaelCBC( $main::imscpKEY, $main::imscpIV, $main::imscpConfig{'DATABASE_PASSWORD'} ));
}

=item END

 Process shutdwon tasks

=cut

END {
    my $self = __PACKAGE__->getInstance();
    $self->{'locks'}->{$_}->release() for keys %{$self->{'locks'}};
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
