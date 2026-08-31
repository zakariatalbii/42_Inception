#!/bin/bash

set -eu

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

mkdir -p /run/php
chown -R www-data:www-data /run/php /var/www/html

if [ ! -f /var/www/html/wp-load.php ]; then
    echo "Downloading WordPress..."
    curl -fsSL https://wordpress.org/latest.tar.gz -o /tmp/wordpress.tar.gz
    tar -xzf /tmp/wordpress.tar.gz --strip-components=1 -C /var/www/html
    rm -f /tmp/wordpress.tar.gz
fi

if [ ! -f /var/www/html/.wp_installed ]; then
    echo "Waiting for MariaDB..."
    i=0
    until mariadb -h "${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${DB_PASSWORD}" -e "SELECT 1" "${MYSQL_DATABASE}" > /dev/null 2>&1; do
        i=$((i + 1))
        if [ "$i" -ge 30 ]; then
            echo "MariaDB is not reachable." >&2
            exit 1
        fi
        sleep 1
    done

    curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
    chmod +x /usr/local/bin/wp

    su -s /bin/bash www-data -c "wp config create \
        --path=/var/www/html \
        --dbname='${MYSQL_DATABASE}' \
        --dbuser='${MYSQL_USER}' \
        --dbpass='${DB_PASSWORD}' \
        --dbhost='${MYSQL_HOST}' \
        --dbcharset=utf8mb4 \
        --skip-check"

    su -s /bin/bash www-data -c "wp core install \
        --path=/var/www/html \
        --url='https://${DOMAIN_NAME}' \
        --title='${WP_TITLE}' \
        --admin_user='${WP_ADMIN_USER}' \
        --admin_email='${WP_ADMIN_EMAIL}' \
        --admin_password='${WP_ADMIN_PASSWORD}' \
        --skip-email"

    su -s /bin/bash www-data -c "wp user create \
        --path=/var/www/html \
        '${WP_USER}' \
        '${WP_USER_EMAIL}' \
        --user_pass='${WP_USER_PASSWORD}' \
        --role=author"

    touch "/var/www/html/.wp_installed"
fi

echo "Starting php-fpm..."
exec php-fpm8.2 -F
