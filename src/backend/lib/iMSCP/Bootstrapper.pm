=head1 NAME

 iMSCP::Bootstrapper - i-MSCP Bootstrapper

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

package iMSCP::Bootstrapper;

use strict;
use warnings;
use autouse 'iMSCP::Crypt' => qw/ decryptRijndaelCBC randomStr /;
use autouse POSIX => 'tzset';
use Carp 'croak';
use Class::Autouse qw/ :nostat iMSCP::Database iMSCP::Requirements /;
use iMSCP::Boolean;
use iMSCP::Debug 'debug';
use iMSCP::EventManager;
use iMSCP::Getopt;
use iMSCP::Provider::Config::JavaProperties;
use iMSCP::Compat::HashrefViaHash;
use iMSCP::Umask '$UMASK';
use Params::Check qw/ check last_error /;
# Make sure that object destructors are called on HUP, PIPE, INT and TERM signals
use sigtrap qw/ die normal-signals /;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 Bootstrap class for i-MSCP

=head1 PUBLIC METHODS

=over 4

=item boot( \%options )

 Boot i-MSCP

 Param hashref \%options Bootstrap options
 Return iMSCP::Bootstrapper, die on failure

=cut

sub boot
{
    my ( $self, $options ) = @_;
    $options //= 'HASH';

    ref $options eq 'HASH' or die( '$options parameter is invalid.' );

    local $Params::Check::PRESERVE_CASE = TRUE;
    $options = check( { nodatabase => { default => TRUE, strict_type => TRUE } }, $options, TRUE ) or die( Params::Check::last_error());

    my $mode = iMSCP::Getopt->context();
    debug( sprintf( 'Booting backend in %s mode....', $mode ));

    # In distribution installer context, the configuration file
    # is loaded by the installer itself
    $self->loadMasterConfig() unless $ENV{'IMSCP_DIST_INSTALLER'};

    # Set timezone unless we are in installer or uninstaller context
    # (needed to show current local timezone in setup dialog)
    unless ( grep ( $mode eq $_, 'installer', 'uninstaller' ) ) {
        $ENV{'TZ'} = $::imscpConfig{'TIMEZONE'} || 'UTC';
        tzset;
    }

    $self->_setupDB() unless $options->{'nodatabase'};
    iMSCP::EventManager->getInstance()->trigger( 'onBoot', $mode );
    $self;
}

=item loadMasterConfig( \%options )

 Load master i-MSCP configuration in readonly mode

 Return iMSCP::Bootstrapper, die on failure

=cut

sub loadMasterConfig
{
    my ( $self ) = @_;

    debug( sprintf( 'Loading i-MSCP master configuration (readonly)...' ));

    my $provider = iMSCP::Provider::Config::JavaProperties->new(
        # The '{CONF_DIR}' template variable is expanded while installation
        GLOB_PATTERN => $ENV{'IMSCP_CONF_DIR'} || '{CONF_DIR}/imscp.conf',
        READONLY     => TRUE
    );

    # Transitional - Config hash will be made available through Application
    # object (singleton) when it will be implemented.
    tie %::imscpConfig, 'iMSCP::Compat::HashrefViaHash', HASHREF => $provider->();
    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setupDB( )

 Setup database

 Return void, die on failure

=cut

sub _setupDB
{
    my ( $self ) = @_;

    $self->_loadEncryptionKeys();

    my $db = iMSCP::Database->getInstance();
    $db->set( $_, $::imscpConfig{$_} ) for qw/ DATABASE_HOST DATABASE_PORT DATABASE_NAME DATABASE_USER /;
    $db->set( 'DATABASE_PASSWORD', decryptRijndaelCBC( $::imscpKEY, $::imscpIV, $::imscpConfig{'DATABASE_PASSWORD'} ));
}

=item _loadEncryptionKeys( )

 Load encryption key and vector, generate them if missing

 Return void

=cut

sub _loadEncryptionKeys
{
    $::imscpKEY = '{KEY}';
    $::imscpIV = '{IV}';

    eval { require "$::imscpConfig{'CONF_DIR'}/imscp-db-keys.pl"; };

    if ( $@
        || $::imscpKEY eq '{KEY}' || length( $::imscpKEY ) != 32
        || $::imscpIV eq '{IV}' || length( $::imscpIV ) != 16
        || ( iMSCP::Getopt->context() eq 'installer' && !-f "$::imscpConfig{'CONF_DIR'}/imscp-db-keys.php" )
    ) {
        debug( 'Missing or invalid i-MSCP key files. Generating a new key files...' );
        -d $::imscpConfig{'CONF_DIR'} or die( sprintf( "%s doesn't exist or is not a directory", $::imscpConfig{'CONF_DIR'} ));

        require Data::Dumper;
        local $Data::Dumper::Indent = FALSE;

        # File must not be created world-readable
        local $UMASK = 0027;

        ( $::imscpKEY, $::imscpIV ) = ( randomStr( 32 ), randomStr( 16 ) );

        for my $file ( qw/ imscp-db-keys.pl imscp-db-keys.php / ) {
            open my $fh, '>', "$::imscpConfig{'CONF_DIR'}/$file" or die(
                sprintf( "Couldn't open %s file for writing: %s", "$::imscpConfig{'CONF_DIR'}/$file", $! )
            );
            print $fh <<"EOF";
@{ [ $file eq 'imscp-db-keys.php' ? '<?php' : "#/usr/bin/perl\n" ]}
# i-MSCP key file @{ [ $file eq 'imscp-db-keys.php' ? '(FrontEnd)' : '(Backend)' ]} - auto-generated by i-MSCP
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
#
# This file must be kept secret !!!

@{ [ Data::Dumper->Dump( [ $::imscpKEY ], [ $file eq 'imscp-db-keys.php' ? 'imscpKEY' : '::imscpKEY' ] ) ] }
@{ [ Data::Dumper->Dump( [ $::imscpIV ], [ $file eq 'imscp-db-keys.php' ? 'imscpIV' : '::imscpIV' ] ) ] }

@{[ $file eq 'imscp-db-keys.php' ? '?>' : "1;\n__END__"]}
EOF
            $fh->close();
        }
    }
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
