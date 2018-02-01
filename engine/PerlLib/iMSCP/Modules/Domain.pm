=head1 NAME

 iMSCP::Modules::Domain - Module for processing of domain entities

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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

package iMSCP::Modules::Domain;

use strict;
use warnings;
use File::Spec;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of domain entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 Get entity type

 Return string entity type

=cut

sub getEntityType
{
    'Domain';
}

=item add()

 Add, change or enable the domain

 Return self, die on failure

=cut

sub add
{
    my ($self) = @_;

    eval { $self->SUPER::add(); };
    $self->{'_dbh'}->do( 'UPDATE domain SET domain_status = ? WHERE domain_id = ?', undef, $@ || 'ok', $self->{'domain_id'} );
    $self;
}

=item delete()

 Delete the domain

 Return self, die on failure

=cut

sub delete
{
    my ($self) = @_;

    eval { $self->SUPER::delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE domain SET domain_status = ? WHERE domain_id = ?', undef, $@, $self->{'domain_id'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM domain WHERE domain_id = ?', undef, $self->{'domain_id'} );
    $self;
}

=item disable()

 Disable the domain

 Return self, die on failure

=cut

sub disable
{
    my ($self) = @_;

    eval { $self->SUPER::disable(); };
    $self->{'_dbh'}->do( 'UPDATE domain SET domain_status = ? WHERE domain_id = ?', undef, $@ || 'disabled', $self->{'domain_id'} );
    $self;
}

=item restore()

 Restore the domain

 Return self, die on failure

=cut

sub restore
{
    my ($self) = @_;

    eval { $self->SUPER::restore(); };
    $self->{'_dbh'}->do( 'UPDATE domain SET domain_status = ? WHERE domain_id = ?', undef, $@ || 'ok', $self->{'domain_id'} );
    $self;
}

=item handleEntity( $domainId )

 Handle the given domain entity

 Param int $domainId Domain unique identifier
 Return self, die on failure

=cut

sub handleEntity
{
    my ($self, $domainId) = @_;

    $self->_loadData( $domainId );

    if ( $self->{'domain_status'} =~ /^to(?:add|change|enable)$/ ) {
        $self->add();
    } elsif ( $self->{'domain_status'} eq 'todelete' ) {
        $self->delete();
    } elsif ( $self->{'domain_status'} eq 'todisable' ) {
        $self->disable();
    } elsif ( $self->{'domain_status'} eq 'torestore' ) {
        $self->restore();
    } else {
        die( sprintf( 'Unknown action (%s) for domain (ID %d)', $self->{'domain_status'}, $domainId ));
    }

    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadData( $domainId )

 Load data

 Param int $domainId Domain unique identifier
 Return void, die on failure

=cut

sub _loadData
{
    my ($self, $domainId) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref(
        "
            SELECT t1.domain_id, t1.domain_admin_id, t1.domain_mailacc_limit, t1.domain_name, t1.domain_status,
                t1.domain_php, t1.domain_cgi, t1.external_mail, t1.web_folder_protection, t1.document_root,
                t1.url_forward, t1.type_forward, t1.host_forward, t1.phpini_perm_config_level AS php_config_level,
                IFNULL(t2.ip_number, '0.0.0.0') AS ip_number,
                t3.private_key, t3.certificate, t3.ca_bundle, t3.allow_hsts, t3.hsts_max_age,
                t3.hsts_include_subdomains,
                t4.mail_on_domain
            FROM domain AS t1
            LEFT JOIN server_ips AS t2 ON (t2.ip_id = t1.domain_ip_id)
            LEFT JOIN ssl_certs AS t3 ON(
                t3.domain_id = t1.domain_id AND t3.domain_type = 'dmn' AND t3.status = 'ok'
            )
            LEFT JOIN (
                SELECT domain_id, COUNT(domain_id) AS mail_on_domain
                FROM mail_users
                WHERE mail_type LIKE 'normal\\_%'
                GROUP BY domain_id
            ) AS t4 ON(t4.domain_id = t1.domain_id)
            WHERE t1.domain_id = ?
        ",
        undef, $domainId
    );
    $row or die( sprintf( 'Data not found for domain (ID %d)', $domainId ));
    %{$self} = ( %{$self}, %{$row} );
}

=item _getData( $action )

 Data provider method for servers and packages

 Param string $action Action
 Return hashref Reference to a hash containing data, die on failure

=cut

sub _getData
{
    my ($self, $action) = @_;

    return $self->{'_data'} if %{$self->{'_data'}};

    my $usergroup = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $main::imscpConfig{'SYSTEM_USER_MIN_UID'}+$self->{'domain_admin_id'} );
    my $homeDir = File::Spec->canonpath( "$main::imscpConfig{'USER_WEB_DIR'}/$self->{'domain_name'}" );
    my $documentRoot = File::Spec->canonpath( "$homeDir/$self->{'document_root'}" );
    my ($ssl, $hstsMaxAge, $hstsIncSub, $phpini) = ( 0, 0, 0, {} );

    if ( $self->{'certificate'} && -f "$main::imscpConfig{'GUI_ROOT_DIR'}/data/certs/$self->{'domain_name'}.pem" ) {
        $ssl = 1;
        if ( $self->{'allow_hsts'} eq 'on' ) {
            $hstsMaxAge = $self->{'hsts_max_age'} || 0;
            $hstsIncSub = $self->{'hsts_include_subdomains'} eq 'on' ? '; includeSubDomains' : '';
        }
    }

    if ( $self->{'domain_php'} eq 'yes' ) {
        $phpini = $self->{'_dbh'}->selectrow_hashref(
            "SELECT * FROM php_ini WHERE domain_id = ? AND domain_type = ?", undef, $self->{'domain_id'}, 'dmn'
        ) || {};
    }

    $self->{'_data'} = {
        ACTION                  => $action,
        STATUS                  => $self->{'domain_status'},
        BASE_SERVER_VHOST       => $main::imscpConfig{'BASE_SERVER_VHOST'},
        BASE_SERVER_IP          => $main::imscpConfig{'BASE_SERVER_IP'},
        BASE_SERVER_PUBLIC_IP   => $main::imscpConfig{'BASE_SERVER_PUBLIC_IP'},
        DOMAIN_ADMIN_ID         => $self->{'domain_admin_id'},
        DOMAIN_ID               => $self->{'domain_id'},
        DOMAIN_NAME             => $self->{'domain_name'},
        DOMAIN_IP               => $main::imscpConfig{'BASE_SERVER_IP'} eq '0.0.0.0' ? '0.0.0.0' : $self->{'ip_number'},
        DOMAIN_TYPE             => 'dmn',
        PARENT_DOMAIN_NAME      => $self->{'domain_name'},
        ROOT_DOMAIN_NAME        => $self->{'domain_name'},
        HOME_DIR                => $homeDir,
        WEB_DIR                 => $homeDir,
        MOUNT_POINT             => '/',
        DOCUMENT_ROOT           => $documentRoot,
        SHARED_MOUNT_POINT      => 0,
        USER                    => $usergroup,
        GROUP                   => $usergroup,
        PHP_SUPPORT             => $self->{'domain_php'},
        PHP_CONFIG_LEVEL        => $self->{'php_config_level'},
        PHP_CONFIG_LEVEL_DOMAIN => $self->{'domain_name'},
        CGI_SUPPORT             => $self->{'domain_cgi'},
        WEB_FOLDER_PROTECTION   => $self->{'web_folder_protection'},
        SSL_SUPPORT             => $ssl,
        HSTS_SUPPORT            => $ssl && $self->{'allow_hsts'} eq 'on',
        HSTS_MAX_AGE            => $hstsMaxAge,
        HSTS_INCLUDE_SUBDOMAINS => $hstsIncSub,
        ALIAS                   => 'dmn' . $self->{'domain_id'},
        FORWARD                 => $self->{'url_forward'} || 'no',
        FORWARD_TYPE            => $self->{'type_forward'} || '',
        FORWARD_PRESERVE_HOST   => $self->{'host_forward'} || 'Off',
        DISABLE_FUNCTIONS       => $phpini->{'disable_functions'}
            || 'exec,passthru,phpinfo,popen,proc_open,show_source,shell,shell_exec,symlink,system',
        MAX_EXECUTION_TIME      => $phpini->{'max_execution_time'} || 30,
        MAX_INPUT_TIME          => $phpini->{'max_input_time'} || 60,
        MEMORY_LIMIT            => $phpini->{'memory_limit'} || 128,
        ERROR_REPORTING         => $phpini->{'error_reporting'} || 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
        DISPLAY_ERRORS          => $phpini->{'display_errors'} || 'off',
        POST_MAX_SIZE           => $phpini->{'post_max_size'} || 8,
        UPLOAD_MAX_FILESIZE     => $phpini->{'upload_max_filesize'} || 2,
        ALLOW_URL_FOPEN         => $phpini->{'allow_url_fopen'} || 'off',
        PHP_FPM_LISTEN_PORT     => ( $phpini->{'id'} // 1 )-1,
        EXTERNAL_MAIL           => $self->{'external_mail'},
        MAIL_ENABLED            => $self->{'external_mail'} eq 'off' && ( $self->{'mail_on_domain'} || $self->{'domain_mailacc_limit'} >= 0 )
    };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
