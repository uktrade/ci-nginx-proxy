#!/bin/bash

set -euo pipefail

# Validate environment variables
: "${PROXY_TARGET:?Set PROXY_TARGET using --env}"
: "${TARGET_PORT:?Set TARGET_PORT using --env}"


echo ">> generating self signed cert"
openssl req -x509 -newkey rsa:4086 \
-subj "/C=XX/ST=XXXX/L=XXXX/O=XXXX/CN=localhost" \
-keyout "/key.pem" \
-out "/cert.pem" \
-days 3650 -nodes -sha256

# Template an nginx.conf
cat <<EOF >/etc/nginx/nginx.conf
user nginx;
worker_processes 2;

events {
  worker_connections 1024;
}
EOF

cat <<EOF >>/etc/nginx/nginx.conf

#upstream rattic {
#  server ${PROXY_TARGET}:${TARGET_PORT};
#}

http {
  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  server {
    listen 443 ssl;
    server_name localhost;
    root /usr/share/nginx/html;
    ssl_certificate /cert.pem;
    ssl_certificate_key /key.pem;

  location / {
    uwsgi_pass  http://${PROXY_TARGET}:${TARGET_PORT};
    uwsgi_param QUERY_STRING    \$query_string;
    uwsgi_param REQUEST_METHOD  \$request_method;
    uwsgi_param CONTENT_TYPE    \$content_type;
    uwsgi_param CONTENT_LENGTH  \$content_length;
    uwsgi_param REQUEST_URI     \$request_uri;
    uwsgi_param PATH_INFO       \$document_uri;
    uwsgi_param DOCUMENT_ROOT   \$document_root;
    uwsgi_param SERVER_PROTOCOL \$server_protocol;
    uwsgi_param HTTPS           \$https if_not_empty;
    uwsgi_param REMOTE_ADDR     \$remote_addr;
    uwsgi_param REMOTE_PORT     \$remote_port;
    uwsgi_param SERVER_PORT     \$server_port;
    uwsgi_param SERVER_NAME     \$server_name;
    
    #proxy_pass http://${PROXY_TARGET}:${TARGET_PORT};
    #proxy_set_header Host \$http_host;
    #proxy_set_header X-Real-IP \$remote_addr;
    #proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    #proxy_set_header X-Forwarded-Proto \$scheme;
  }
  
  }
}
EOF


# Launch nginx in the foreground
/usr/sbin/nginx -g "daemon off;"
