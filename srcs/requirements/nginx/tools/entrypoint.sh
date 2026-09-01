#!/bin/bash

set -eu

mkdir -p /etc/nginx/ssl

if [ ! -s /etc/nginx/ssl/inception.key ] || [ ! -s /etc/nginx/ssl/inception.crt ]; then
    echo "Generating local self-signed TLS certificate..."
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/inception.key \
        -out /etc/nginx/ssl/inception.crt \
        -days 365 \
        -subj "/CN=${DOMAIN_NAME}" \
        -addext "subjectAltName=DNS:${DOMAIN_NAME}"
    chmod 600 /etc/nginx/ssl/inception.key
fi

nginx -t

echo "Starting NGINX server..."
exec nginx -g "daemon off;"
