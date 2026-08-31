#!/bin/bash

set -eu

DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB data directory..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db > /dev/null
fi

if [ ! -f "/var/lib/mysql/.${MYSQL_DATABASE}_initialized" ]; then
    echo "Starting temporary MariaDB server..."
    mariadbd --user=mysql --datadir=/var/lib/mysql --skip-networking --socket=/run/mysqld/init.sock &
    TMP_PID="$!"

    i=0
    until mariadb-admin --socket=/run/mysqld/init.sock ping --silent > /dev/null 2>&1; do
        i=$((i + 1))
        if [ "$i" -ge 30 ]; then
            echo "MariaDB failed to become ready." >&2
            kill "$TMP_PID" 2> /dev/null || true
            exit 1
        fi
        sleep 1
    done

    mariadb --socket=/run/mysqld/init.sock << SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

    mariadb-admin --socket=/run/mysqld/init.sock -u root -p"$DB_ROOT_PASSWORD" shutdown
    wait "$TMP_PID" 2> /dev/null || true
    touch "/var/lib/mysql/.${MYSQL_DATABASE}_initialized"
fi

rm -f /run/mysqld/init.sock

exec mariadbd --user=mysql --datadir=/var/lib/mysql
