server {
    # SECTION listen BEGIN.
    listen {LISTEN};
    # SECTION listen END.

    server_name {DOMAIN_NAME} {SERVER_ALIASES};

    # FIXME check format (default to combined)
    # It must include I/O bytes and be compatible with AWStats
    access_log {HTTPD_LOG_DIR}/access.log;
    error_log {HTTPD_LOG_DIR}/error.log crit;

    # SECTION dmn BEGIN.
    root {USER_WEB_DIR}/domain_disabled_pages;

    # SECTION ssl BEGIN.
    ssl_certificate {CERTIFICATE};
    ssl_certificate_key {CERTIFICATE};
    add_header Strict-Transport-Security "max-age={HSTS_MAX_AGE}{HSTS_INCLUDE_SUBDOMAINS}";
    # SECTION ssl END.

    index index.html;
    disable_symlinks off;

    location ~ ^/(?!(?:images/.+|index\.html|$)) {
        return 303 {HTTP_URI_SCHEME}www.{DOMAIN_NAME}/;
    }
    # SECTION dmn END.

    # SECTION fwd BEGIN.
    location ~ ^/((?!\.well-known/).*) {
        return {FORWARD_TYPE} {FORWARD}$1;
    }
    # SECTION fwd END.
}
