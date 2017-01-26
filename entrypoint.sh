#!/bin/bash

set -euo pipefail

# Validate environment variables
: "${REDIRECT_DEST:?Set REDIRECT_DEST using --env}"
: "${REDIRECT_CODE:?Set REDIRECT_CODE using --env}"
: "${HOST:?Set HOST using --env}"
: "${SSL_CERT:?Set SSL_CERT using --env}"
: "${SSL_KEY:?Set SSL_KEY using --env}"

# SSL certificate
cat <<EOF > /server.crt
${SSL_CERT}
EOF

# SSL key
cat <<EOF > /server.key
${SSL_KEY}
EOF

# Template an nginx.conf
cat <<EOF >/etc/nginx/nginx.conf
user nginx;
worker_processes 2;

events {
  worker_connections 1024;
}
EOF

cat <<EOF >>/etc/nginx/nginx.conf

http {
  server_tokens off;
  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  server {
    server_name ${HOST} www.${HOST};
    expires 1h;
    add_header Cache-Control "public, must-revalidate";
    return ${REDIRECT_CODE} ${REDIRECT_DEST}\$request_uri;
  }

  server {
    listen 443 ssl;
    server_name ${HOST} www.${HOST};
    expires 1h;
    add_header Cache-Control "public, must-revalidate";
    ssl_certificate /server.crt;
    ssl_certificate_key /server.key;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_stapling on;
    ssl_stapling_verify on;
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    return ${REDIRECT_CODE} ${REDIRECT_DEST}\$request_uri;
  }
}
EOF

echo "Redirecting to ${REDIRECT_DEST} (HTTP ${REDIRECT_CODE})"

# Launch nginx in the foreground
/usr/sbin/nginx -g "daemon off;"
