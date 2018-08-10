=head1 NAME

 Package::Setup::PostfixSRS - i-MSCP Postfix SRS

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

package Package::Setup::PostfixSRS;

use strict;
use warnings;
use iMSCP::Debug qw/ error /;
use iMSCP::EventManager;
use iMSCP::File;
use iMSCP::Service;
use Servers::mta;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 Provides Sender Rewriting Scheme (SRS) support for Postfix via TCP-based lookup tables.

 Project homepage: https://github.com/roehling/postsrsd

=head1 PUBLIC METHODS

=over 4

=item preinstall( )

 Process preinstall tasks
 
 Return int 0 on success, other on failure
 
=cut

sub preinstall
{
    my ( $self ) = @_;

    return 0 unless $::imscpConfig{'POSTFIX_SRS'} eq 'postsrsd';

    $self->stop();
}

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ( $self ) = @_;

    return 0 unless $::imscpConfig{'POSTFIX_SRS'} eq 'postsrsd';

    my $rs = $self->_setupPostsrsDaemon();

    $rs ||= Servers::mta->factory()->postconf( (
        sender_canonical_maps       => {
            action => 'add',
            values => [ 'tcp:127.0.0.1:10001' ]
        },
        sender_canonical_classes    => {
            action => 'replace',
            values => [ 'envelope_sender' ]
        },
        recipient_canonical_maps    => {
            action => 'add',
            values => [ 'tcp:127.0.0.1:10002' ]
        },
        recipient_canonical_classes => {
            action => 'add',
            values => [ 'envelope_recipient', 'header_recipient' ]
        }
    ));
}

=item postinstall( )

 Process postinstall tasks

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ( $self ) = @_;

    return 0 unless $::imscpConfig{'POSTFIX_SRS'} eq 'postsrsd';

    local $@;
    eval { iMSCP::Service->getInstance()->enable( 'postsrsd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            push @{ $_[0] }, [ sub { $self->start(); }, 'Postfix SRS service' ];
            0;
        },
        $self->getPriority()
    );
}

=item start( )

 Start Postfix SRS service
 
 Return int 0 on success, other on failure

=cut

sub start
{
    local $@;
    eval { iMSCP::Service->getInstance()->start( 'postsrsd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item stop( )

 Stop Postfix SRS service
 
 Return int 0 on success, other on failure

=cut

sub stop
{
    local $@;
    eval { iMSCP::Service->getInstance()->stop( 'postsrsd' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item getPriority( )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    7;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return Package::Setup::PostfixSRS

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'eventManager'} = iMSCP::EventManager->getInstance();
    $self;
}

=item _setupPostsrsDaemon( )

 Setup postsrs daemon

 Return int 0 on success, other on failure

=cut

sub _setupPostsrsDaemon
{
    my ( $self ) = @_;

    my $file = iMSCP::File->new( filename => '/etc/default/postsrsd' );
    my $fileContent = $file->getAsRef();
    return 1 unless defined $fileContent;

    ${ $fileContent } =~ s/^(SRS_DOMAIN\s*=)[^\n]+/$1 $::imscpConfig{'SERVER_HOSTNAME'};/m;

    $file->save() || 0;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
