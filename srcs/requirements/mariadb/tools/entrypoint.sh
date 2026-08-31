#!/bin/bash

set -e

DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_PASSWORD=$(cat /run/secrets/db_password)

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -d "/var/lib/mysql/mysql" ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null

    mariadbd --user=mysql --skip-networking &
    TEMP_PID="$!"

    i=0
    until mariadb-admin ping --silent >/dev/null 2> /dev/null; do
        i=$((i + 1))
        if [ "$i" -ge 30 ]; then
            echo "MariaDB failed to become ready." >&2
            kill "$TEMP_PID" 2> /dev/null || true
            exit 1
        fi
        sleep 1
    done

    mariadb -u root << SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

    mysqladmin -u root -p"${DB_ROOT_PASSWORD}" shutdown
fi

exec mariadbd --user=mysql --datadir=/var/lib/mysql
