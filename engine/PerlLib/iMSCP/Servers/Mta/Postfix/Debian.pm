=head1 NAME

 iMSCP::Servers::Mta::Postfix::Debian - i-MSCP (Debian) Postfix server implementation

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

package iMSCP::Servers::Mta::Postfix::Debian;

use strict;
use warnings;
use Class::Autouse qw/ :nostat iMSCP::ProgramFinder /;
use File::Basename;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Service;
use version;
use parent 'iMSCP::Servers::Mta::Postfix::Abstract';

our $VERSION = '2.0.0';

=head1 DESCRIPTION

 i-MSCP (Debian) Postfix server implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 See iMSCP::Servers::Abstract::install()

=cut

sub install
{
    my ( $self ) = @_;

    $self->SUPER::install();
    $self->_cleanup();
}

=item postinstall( )

 See iMSCP::Servers::Abstract::postinstall()

=cut

sub postinstall
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->enable( 'postfix' );
    $self->SUPER::postinstall();
}

=item uninstall( )

 See iMSCP::Servers::Mta::Postfix::uninstall()

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->SUPER::uninstall();
    $self->_restoreConffiles();

    my $srvProvider = iMSCP::Service->getInstance();
    $srvProvider->restart( 'postfix' ) if $srvProvider->hasService( 'postfix' ) && $srvProvider->isRunning( 'postfix' );
}

=item dpkgPostInvokeTasks()

 See iMSCP::Servers::Abstract::dpkgPostInvokeTasks()

=cut

sub dpkgPostInvokeTasks
{
    my ( $self ) = @_;

    return unless iMSCP::ProgramFinder::find( 'postconf' );

    $self->_setVersion();
}

=item start( )

 See iMSCP::Servers::Abstract::start()

=cut

sub start
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->start( 'postfix' );
}

=item stop( )

 See iMSCP::Servers::Abstract::stop()

=cut

sub stop
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->stop( 'postfix' );
}

=item restart( )

 See iMSCP::Servers::Abstract::restart()

=cut

sub restart
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->restart( 'postfix' );
}

=item reload( )

 See iMSCP::Servers::Abstract::reload()

=cut

sub reload
{
    my ( $self ) = @_;

    iMSCP::Service->getInstance()->reload( 'postfix' );
}

=item getAvailableDbDrivers

 See iMSCP::Servers::Mta::Abstract::getAvailableDbDrivers()

=cut

sub getAvailableDbDrivers
{
    my ( $self ) = @_;

    {
        CDB   => {
            desc    => 'A read-optimized structure (recommended)',
            class   => 'iMSCP::Servers::Mta::Postfix::Driver::Database::Cdb',
            default => TRUE
        },
        BTree => {
            desc  => 'A sorted, balanced tree structure',
            class => 'iMSCP::Servers::Mta::Postfix::Driver::Database::Btree'
        },
        Hash  => {
            desc  => 'An indexed file type based on hashing',
            class => 'iMSCP::Servers::Mta::Postfix::Driver::Database::Hash'
        }
    };
}

=back

=head1 PRIVATE METHODS

=over 4

=item _cleanup( )

 Process cleanup tasks

 Return void, die on failure

=cut

sub _cleanup
{
    my ( $self ) = @_;

    return unless version->parse( $::imscpOldConfig{'PluginApi'} ) < version->parse( '1.6.0' );

    iMSCP::File->new( filename => "$self->{'cfgDir'}/postfix.old.data" )->remove();
}

=item _restoreConffiles( )

 Restore configuration files

 Return void, die on failure

=cut

sub _restoreConffiles
{
    return unless -d '/etc/postfix';

    for my $file ( '/usr/share/postfix/main.cf.debian', '/usr/share/postfix/master.cf.dist' ) {
        next unless -f $file;
        iMSCP::File->new( filename => $file )->copy( '/etc/postfix/' . basename( $file, '.debian', '.dist' ));
    }

    my $rs = execute( 'newaliases', \my $stdout, \my $stderr );
    debug( $stdout ) if $stdout;
    !$rs or die( $stderr || 'Unknown error' );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
