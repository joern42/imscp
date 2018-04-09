<VirtualHost {DOMAIN_IPS}>
    ServerAdmin webmaster@{DOMAIN_NAME}
    ServerName {DOMAIN_NAME}
    ServerAlias {SERVER_ALIASES}

    DocumentRoot {DOCUMENT_ROOT}

    LogLevel error
    ErrorLog {HTTPD_LOG_DIR}/{DOMAIN_NAME}/error.log

    Alias /errors/ {HOME_DIR}/errors/

    # SECTION ssl BEGIN.
    SSLEngine On
    SSLCertificateFile {CERTIFICATE}
    Header always set Strict-Transport-Security "max-age={HSTS_MAX_AGE}{HSTS_INCLUDE_SUBDOMAINS}"
    # SECTION ssl ENDING.

    # SECTION dmn BEGIN.
    # SECTION itk BEGIN.
    AssignUserID {USER} {GROUP}
    # SECTION itk ENDING.

    # SECTION suexec BEGIN.
    SuexecUserGroup {USER} {GROUP}
    # SECTION suexec ENDING.

    <Directory {DOCUMENT_ROOT}>
        DirectoryIndex index.html index.xhtml index.htm
        Options FollowSymLinks
        Require all granted
        # SECTION custom document root BEGIN.
        # SECTION custom document root ENDING.
    </Directory>

    # SECTION cgi BEGIN.
    Alias /cgi-bin/ {WEB_DIR}/cgi-bin/
    <Directory {WEB_DIR}/cgi-bin>
        AllowOverride AuthConfig Indexes Limit Options=Indexes,MultiViews \
          Fileinfo=RewriteEngine,RewriteOptions,RewriteBase,RewriteCond,RewriteRule Nonfatal=Override
        DirectoryIndex index.cgi index.pl index.py index.rb
        Options FollowSymLinks ExecCGI
        AddHandler cgi-script .cgi .pl .py .rb
        Require all granted
    # SECTION cgi-bin addons BEGIN.
    # SECTION cgi-bin addons ENDING.
    </Directory>
    # SECTION cgi ENDING.
    # SECTION dmn ENDING.

    # SECTION fwd BEGIN.
    <Directory {DOCUMENT_ROOT}>
        Options FollowSymLinks
        AllowOverride AuthConfig Indexes Limit Options=Indexes,MultiViews \
          Fileinfo=RewriteEngine,RewriteOptions,RewriteBase,RewriteCond,RewriteRule Nonfatal=Override
        # SECTION custom document root BEGIN.
        # SECTION custom document root ENDING.
        Require all granted
    </Directory>

    # SECTION std_fwd BEGIN.
    RedirectMatch {FORWARD_TYPE} ^/((?!(?:errors|\.well-known)/).*) {FORWARD}$1
    # SECTION std_fwd ENDING.
    # SECTION proxy_fwd BEGIN.
    # SECTION ssl_proxy BEGIN.
    SSLProxyEngine on
    # SECTION ssl_proxy ENDING.
    RequestHeader set X-Forwarded-Proto "{X_FORWARDED_PROTOCOL}"
    RequestHeader set X-Forwarded-Port {X_FORWARDED_PORT}
    ProxyPreserveHost {FORWARD_PRESERVE_HOST}
    ProxyPassMatch ^/((?!(?:errors|\.well-known)/).*) {FORWARD}$1 retry=30 timeout=7200
    ProxyPassReverse / {FORWARD}
    # SECTION proxy_fwd ENDING.
    # SECTION fwd ENDING.

    # SECTION addons BEGIN.
    # SECTION addons ENDING.

    Include {HTTPD_CUSTOM_SITES_DIR}/{DOMAIN_NAME}.conf
</VirtualHost>
