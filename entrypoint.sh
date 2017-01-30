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
    proxy_pass http://${PROXY_TARGET}:${TARGET_PORT};
    proxy_set_header Host \$http_host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
  
  }
}
EOF


# Launch nginx in the foreground
/usr/sbin/nginx -g "daemon off;"
