server {
    # SECTION listen BEGIN.
    listen {LISTEN};
    # SECTION listen END.

    server_name {DOMAIN_NAME} {SERVER_ALIASES};

    root {DOCUMENT_ROOT};

    # FIXME check format (default to combined)
    # It must include I/O bytes and be compatible with AWStats
    access_log {HTTPD_LOG_DIR}/access.log;
    error_log {HTTPD_LOG_DIR}/error.log crit;

    location ^~ /errors/ {
        root {HOME_DIR};
        expires 30d;
    }

    error_page 401 /errors/401.html;
    error_page 403 /errors/403.html;
    error_page 404 /errors/404.html;
    error_page 500 /errors/500.html;
    error_page 502 /errors/502.html;
    error_page 503 /errors/503.html;

    # SECTION ssl BEGIN.
    ssl_certificate {CERTIFICATE};
    ssl_certificate_key {CERTIFICATE};
    add_header Strict-Transport-Security "max-age={HSTS_MAX_AGE}{HSTS_INCLUDE_SUBDOMAINS}";
    # SECTION ssl END.

    # SECTION dmn BEGIN.
    location / {
        index index.html index.xhtml index.htm;
        disable_symlinks off;
        # SECTION document root addons BEGIN.
        # SECTION document root addons END.
    }

    # SECTION cgi BEGIN.
    location /cgi-bin/ {
        gzip off;
        root {WEB_DIR};
        index index.cgi index.pl index.py index.rb;
        disable_symlinks off;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        include /etc/nginx/fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        # SECTION cgi-bin addons BEGIN.
        # SECTION cgi-bin addons END.
    }
    # SECTION cgi END.
    # SECTION dmn END.

    # SECTION fwd BEGIN.
    location / {
        disable_symlinks off;
        # SECTION document root addons BEGIN.
        # SECTION document root addons END.
    }

    # SECTION std_fwd BEGIN.
    location ~ ^/((?!(?:errors|\.well-known)/).*) {
        return {FORWARD_TYPE} {FORWARD}$1;
    }
    # SECTION std_fwd END.

    # SECTION proxy_fwd BEGIN.
    location ~ ^/((?!(?:errors|\.well-known)/).*) {
        proxy_intercept_errors on;

        # SECTION proxy_host BEGIN.
        proxy_set_header Host $host;
        # SECTION proxy_host END.

        proxy_set_header X-Forwarded-Proto "{X_FORWARDED_PROTOCOL}";
        proxy_set_header X-Forwarded-Port {X_FORWARDED_PORT};
        proxy_pass {FORWARD};
    }
    # SECTION proxy_fwd END.
    # SECTION fwd END.

    # SECTION addons BEGIN.
    # SECTION addons END.

    include {HTTPD_CUSTOM_SITES_DIR}/{DOMAIN_NAME}.conf;
}
