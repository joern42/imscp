[uwsgi]
plugins = cgi

socket = {UWSGI_RUN_DIR}/{USER}/socket
pid = {UWSGI_RUN_DIR}/{USER}/pid

chown-socket = {HTTPD_USER}:{HTTPD_GROUP}
chmod-socket = 660

process = {UWSGI_MAX_CGI_PROCESSES}
threads = {UWSGI_MAX_CGI_THREADS}

uid = {USER}
gid = {GROUP}

cgi = {DOCUMENT_ROOT}
cgi-allowed-ext = .cgi
cgi-allowed-ext = .rb
cgi-allowed-ext = .pl
cgi-allowed-ext = .py
