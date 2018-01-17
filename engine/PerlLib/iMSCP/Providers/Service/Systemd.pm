=head1 NAME

 iMSCP::Providers::Service::Systemd - Systemd base service provider implementation

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

package iMSCP::Providers::Service::Systemd;

use strict;
use warnings;
use Carp qw/ croak /;
use File::Basename;
use File::Spec;
use iMSCP::File;
use parent 'iMSCP::Providers::Service::Sysvinit';

# Commands used in that package
our %COMMANDS = (
    systemctl => '/bin/systemctl'
);

# Paths in which service units must be searched
my @UNITFILEPATHS = (
    '/etc/systemd/system',
    '/lib/systemd/system',
    '/usr/local/lib/systemd/system',
    '/usr/lib/systemd/system'
);

=head1 DESCRIPTION

 Systemd base service provider implementation.

 See https://www.freedesktop.org/wiki/Software/systemd/

=head1 PUBLIC METHODS

=over 4

=item isEnabled( $unit )

 See iMSCP::Providers::Service::Interface::isEnabled()

=cut

sub isEnabled
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    # We need to catch STDERR here as we do not want report it as error
    my $ret = $self->_exec( [ $COMMANDS{'systemctl'}, 'is-enabled', $self->resolveUnit( $unit ) ], \ my $stdout, \my $stderr );

    # The indirect state indicates that the unit is not enabled.
    return 0 if $stdout eq 'indirect';

    $ret == 0;
}

=item enable( $unit )

 See iMSCP::Providers::Service::Interface::enable()

=cut

sub enable
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    # We make use of the --force flag to overwrite any conflicting symlinks.
    # This is particularly usefull in case the unit provides an alias that is
    # also provided as a SysVinit script and which has been masked. For instance:
    # - mariadb.service unit which also provide the mysql.service unit as alias
    # - mysql SysVinit script which is masked (/etc/systemd/system/mysql.service => /dev/null)
    # In such a case, and without the --force option, Systemd would fails to create the symlink
    # for the the mysql.service alias as the mysql.service symlink would already exist.
    $self->unmask( $unit ) && $self->_exec( [ $COMMANDS{'systemctl'}, '--force', '--quiet', 'enable', $self->resolveUnit( $unit ) ] ) == 0;
}

=item disable( $unit )

 See iMSCP::Providers::Service::Interface::disable()

=cut

sub disable
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    $self->_exec( [ $COMMANDS{'systemctl'}, '--quiet', 'disable', $self->resolveUnit( $unit ) ] ) == 0;
}

=item mask( $unit )

 Mask the given unit
 
 Return bool TRUE on success, croak on failure

=cut

sub mask
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    return 0 unless $self->disable( $unit );

    # Units located in the /etc/systemd/system directory cannot be masked
    unless ( index( $self->resolveUnit( $unit ), '/etc/systemd/system/' ) == 0 ) {
        return $self->_exec( [ $COMMANDS{'systemctl'}, '--quiet', 'mask', $self->resolveUnit( $unit ) ] ) == 0;
    }

    1;
}

=item unmask( $unit )

 Unmask the given unit
 
 Return bool TRUE on success, croak on failure

=cut

sub unmask
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    # Units located in the /etc/systemd/system directory cannot be masked
    unless ( index( $self->resolveUnit( $unit ), '/etc/systemd/system/' ) == 0 ) {
        return $self->_exec( [ $COMMANDS{'systemctl'}, '--quiet', 'unmask', $self->resolveUnit( $unit ) ] ) == 0;
    }

    1;
}

=item remove( $unit )

 See iMSCP::Providers::Service::Interface::remove()

=cut

sub remove
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    return 0 unless $self->stop( $unit ) && $self->unmask( $unit ) && $self->disable( $unit );

    my $unitFilePath = eval { $self->resolveUnit( $unit, 'withpath', 'nocache' ); };
    if ( defined $unitFilePath
        # We do not want remove units that are shipped by distribution packages
        && index( $unitFilePath, '/etc/systemd/system/' ) != 0
    ) {
        return 0 unless iMSCP::File->new( filename => $unitFilePath )->delFile() == 0;
        return $self->_exec( [ $COMMANDS{'systemctl'}, 'daemon-reload' ] ) == 0;
    }

    1;
}

=item start( $unit )

 See iMSCP::Providers::Service::Interface::start()

=cut

sub start
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    $self->_exec( [ $COMMANDS{'systemctl'}, 'start', $self->resolveUnit( $unit ) ] ) == 0;
}

=item stop( $unit )

 See iMSCP::Providers::Service::Interface::stop()

=cut

sub stop
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    $self->_exec( [ $COMMANDS{'systemctl'}, 'stop', $self->resolveUnit( $unit ) ] ) == 0;
}

=item restart( $unit )

 See iMSCP::Providers::Service::Interface::restart()

=cut

sub restart
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    $self->_exec( [ $COMMANDS{'systemctl'}, 'restart', $self->resolveUnit( $unit ) ] ) == 0;
}

=item reload( $service )

 See iMSCP::Providers::Service::Interface::reload()

=cut

sub reload
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    $self->_exec( [ $COMMANDS{'systemctl'}, 'reload-or-restart', $self->resolveUnit( $unit ) ] ) == 0;
}

=item isRunning( $service )

 See iMSCP::Providers::Service::Interface::isRunning()

=cut

sub isRunning
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    $self->_exec( [ $COMMANDS{'systemctl'}, 'is-active', $self->resolveUnit( $unit ) ] ) == 0;
}

=item hasService( $unit )

 See iMSCP::Providers::Service::Interface::hasService()

=cut

sub hasService
{
    my ($self, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    eval { $self->resolveUnit( $unit ); };
}

=item resolveUnit( $unit [, $withpath =  FALSE, [ $nocache = FALSE ] ] )

 Resolves the given unit

 Units can be aliased (have an alternative name), by creating a symlink from
 the new name to the existing name in one of the unit search paths.
 
 Due to unexpeted behaviors when we're acting on alias units, this method make
 it possible to always act on the aliased units by resolving them.
 
 See the following reports for a better understanding of the situation
  - https://github.com/systemd/systemd/issues/7875
  - https://github.com/systemd/systemd/issues/7874

 A fallback for SysVinit scripts is also provided. If $unit is not a native
 Systemd unit and that a SysVinit match the $unit name (without the .service
 suffix), its name or path is returned.
 
 Units are resolved only once. However, it is possible to force new resolving by
 passing the $nocache flag.

 Param string $unit Unit name
 Param bool withpath If true, full unit path will be returned
 Param bool $nocache OPTIONAL If true, no cache will be used
 Return string real unit file path or name, SysVinit file path or name, croak if the unit cannot be resolved

=cut

sub resolveUnit
{
    my ($self, $unit, $withpath, $nocache) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    # Make sure that units are resolved only once
    CORE::state %resolved;

    if ( $nocache ) {
        delete $resolved{$unit} if $nocache;
    } elsif ( exists $resolved{$unit} ) {
        defined $resolved{$unit} or croak( sprintf( "Couldn't resolve the %s unit", $unit ));
        return $resolved{$unit}->[$withpath ? 0 : 1];
    }

    my $unitFilePath = eval { $self->_searchUnitFile( $unit, $nocache ); };
    if ( $@ ) {
        # For the SysVinit scripts, we want operate only on services
        ( $unit, undef, my $suffix ) = fileparse( $unit, qr/\.[^.]*/ );
        if ( grep( $suffix eq $_, '', '.service') ) {
            local $@;
            $unitFilePath = eval { $self->_searchInitScript( $unit ) };

            if ( defined $unitFilePath ) {
                $resolved{$unit} = [ $unitFilePath, $unit ];
                goto &{resolveUnit};
            }
        }

        $resolved{$unit} = undef unless $nocache;
        croak( sprintf( "Couldn't resolve the %s unit: %s", $unit, $@ ));
    }

    $unitFilePath = readlink( $unitFilePath ) or croak( sprintf( "Couldn't resolve the %s unit: %s", $unit, $! )) if -l $unitFilePath;
    my $unitReal = basename( $unitFilePath );

    if ( $nocache ) {
        return $unitFilePath if $withpath;
        return $unit;
    }

    $resolved{$unit} = [ $unitFilePath, $unitReal ];
    goto &{resolveUnit};
}

=back

=head1 PRIVATE METHODS

=over 4

=item _searchUnitFile( $unit )

 Search the given unit file in all available paths

 Param string $unit Unit name
 Return string unit file path on success, croak on failure

=cut

sub _searchUnitFile
{
    my (undef, $unit) = @_;

    defined $unit or croak( 'Missing or undefined $unit parameter' );

    ( undef, undef, my $suffix ) = fileparse( $unit, qw/ .automount .device .mount .path .scope .service .slice .socket .swap .timer / );
    $unit .= '.service' unless $suffix;

    for ( @UNITFILEPATHS ) {
        my $filepath = File::Spec->join( $_, $unit );
        return $filepath if -f $filepath;
    }

    croak( sprintf( "Unit %s not found", $unit ));
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
