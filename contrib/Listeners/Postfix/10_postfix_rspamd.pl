# i-MSCP iMSCP::Listener::Postfix::Rspamd listener file
# Copyright (C) 2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA

# Inject required postfix(1) parameters for rspamd(8)
# See https://rspamd.com/doc/integration.html
# See https://i-mscp.net/index.php/Thread/18579-I-MSCP-and-rspamd/?postID=58092#post58092
# See http://www.postfix.org/MILTER_README.html
#
# Howto setup:
# - Install this listener file in the /etc/imscp/listeners.d directory
# - Trigger an i-MSCP reconfiguration by running: perl /var/www/imscp/backend/setup/imscp-reconfigure -danv

package iMSCP::Listener::Postfix::Rspamd;

our $VERSION = '1.1.1';

use strict;
use warnings;
use iMSCP::EventManager;
use iMSCP::Servers::Mta;
use version;

version->parse( "$::imscpConfig{'PluginApi'}" ) >= version->parse( '1.6.0' ) or die(
    sprintf( "The 10_postfix_rspamd.pl listener file version %s requires i-MSCP >= 1.6.0", $VERSION )
);

# We register this listener only in setup context as the 'afterMtaBuildConf'
# event is not triggered in other contexts.
if ( defined $main::execmode && $main::execmode eq 'setup' ) {
    iMSCP::EventManager->getInstance()->register( 'afterPostfixConfigure', \&configurePostfix, -100 );
}

# In case the i-MSCP SA plugin has just been installed or enabled, we need to
# redo the job because that plugin puts its smtpd_milters and non_smtpd_milters
# parameters at first position what we want avoid as mails must first pass
# through the rspamd(8) filter.
iMSCP::EventManager->getInstance()->register( [ 'onAfterInstallPlugin', 'onAfterEnablePlugin' ], sub {
    return configurePostfix() if $_[0] eq 'SpamAssassin';
} );

# Inject/Update required parameters in posfix(1) main.cf file for rspamd(8)
sub configurePostfix
{
    iMSCP::Servers::Mta->factory()->postconf(
        milter_default_action => {
            # Our i-MSCP SA, ClamAV ... plugins set this value to 'tempfail'
            # but 'accept' is OK if we want ignore milter failures and accept
            # the mails, even if those are potentially SPAMs.
            values => [ 'accept' ]
        },
        # We want filter incoming mails, that is, those that arrive via
        # smtpd(8) server.
        smtpd_milters         => {
            action => 'add',
            values => [ 'inet:localhost:11332' ],
            # Make sure that rspamd(8) filtering is processed first.
            before => qr/.*/
        },
        # This was not specified in specifications provided by UncleSam.
        # However, we want also filter customer outbound mails, that is,
        # those that arrive via sendmail(1).
        non_smtpd_milters     => {
            action => 'add',
            values => [ 'inet:localhost:11332' ],
            # Make sure that rspamd(8) filtering is processed first.
            before => qr/.*/
        },
        # MILTER mail macros required for rspamd(8)
        # There should be no clash with our i-MSCP SA, ClamAV ... plugins as
        # these don't make use of those macros.
        milter_mail_macros    => {
            values => [ 'i {mail_addr} {client_addr} {client_name} {auth_authen}' ]
        },
        # This should be default value already. We add it here for safety only.
        # (see postconf -d milter_protocol)
        milter_protocol       => {
            values => [ 6 ]
        }
    );
}

1;
__END__
