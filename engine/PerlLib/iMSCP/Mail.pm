=head1 NAME

 iMSCP::Mail - Send warning or error message to system administrator

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

package iMSCP::Mail;

use strict;
use warnings;
use Carp qw/ croak /;
use Encode;
use iMSCP::ProgramFinder;
use MIME::Entity;
use Text::Wrap;
use parent 'iMSCP::Common::Object';

$Text::Wrap::huge = 'wrap';
$Text::Wrap::columns = 75;
$Text::Wrap::break = qr/[\s\n\|]/;

=head1 DESCRIPTION

 Send warning or error message to system administrator

=head1 PUBLIC METHODS

=over 4

=item errmsg( $message )

 Send an error message to system administrator

 Param string Error message to be sent
 Return self, die on failure
 
=cut

sub errmsg
{
    my ( $self, $message ) = @_;

    defined $message or croak( '$message parameter is not defined' );

    return $self unless length $message;

    chomp( $message );

    $self->_sendMail( 'i-MSCP - An error has been raised', <<"EOF", 'error' );
One or many unexpected errors were raised in i-MSCP backend:

$message
EOF
    $self
}

=item warnMsg( $message )

 Send a warning message to system administrator

 Param string $message Warning message to be sent
 Return self, die on failure
 
=cut

sub warnMsg
{
    my ( $self, $message ) = @_;

    defined $message or croak( '$message parameter is not defined' );

    return $self unless length $message;

    chomp( $message );

    $self->_sendMail( 'i-MSCP - A warning has been raised', <<"EOF", 'warning' );
One or many unexpected warnings were raised in i-MSCP backend:

$message
EOF
    $self
}

=back

=head1 PRIVATE METHODS

=over 4

=item _sendMail($subject, $message, $severity)

 Send a message to system administrator

 Param string $subject Message subject
 Param string $message Message to be sent
 Param string $severity Message severity
 Return void, die on failure
 
=cut

sub _sendMail
{
    my ( undef, $subject, $message, $severity ) = @_;

    my $sendmail = iMSCP::ProgramFinder::find( 'sendmail' ) or die( "Couldn't find sendmail executable in \$PATH" );
    my $hostname = $::imscpConfig{'BASE_SERVER_VHOST'} || `hostname -f`;
    chomp( $hostname );
    my $out = MIME::Entity->new()->build(
        From       => "i-MSCP ($hostname) <noreply\@$hostname>",
        To         => $::imscpConfig{'DEFAULT_ADMIN_ADDRESS'} || 'root',
        Subject    => $subject,
        Type       => 'text/plain; charset=utf-8',
        Encoding   => '8bit',
        Data       => encode( 'UTF-8', wrap( '', '', <<"EOF" )),
Dear administrator,

This is an automatic email sent by the i-MSCP backend:
 
Server name: $::imscpConfig{'SERVER_HOSTNAME'}
Server IP: $::imscpConfig{'BASE_SERVER_PUBLIC_IP'}
Version: $::imscpConfig{'Version'}
Build: $::imscpConfig{'BuildDate'}
Message severity: $severity

==========================================================================
$message
==========================================================================

Please do not reply to this email.

___________________________
i-MSCP Backend Mailer
        EOF
        'X-Mailer' => 'i-MSCP Mailer (backend)'
    );

    open my $fh, '|-', $sendmail, '-t', '-oi', '-f', "noreply\@$hostname" or die( sprintf( "Couldn't pipe to sendmail: %s", $! ));
    $out->print( $fh );
    close $fh;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
