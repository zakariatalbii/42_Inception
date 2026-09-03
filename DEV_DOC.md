# Inception — Developer Documentation

## 1. Purpose

This document explains how the infrastructure is built, configured, launched and maintained by a developer.

The project contains three custom Docker images:

```text
NGINX      -> HTTPS / FastCGI gateway
WordPress  -> PHP-FPM / WordPress application
MariaDB    -> database
```

The Compose project is defined in `srcs/docker-compose.yml` and the main developer interface is the root `Makefile`.

## 2. Prerequisites

Install or provide:

- Docker Engine
- Docker Compose v2
- GNU Make
- Bash
- `sudo`
- a Linux environment suitable for Docker
- Internet access for Debian package installation and first-time WordPress/WP-CLI downloads

Verify:

```bash
docker --version
docker compose version
make --version
```

## 3. Repository layout

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
├── secrets/
│   ├── db_root_password
│   ├── db_password
│   ├── wp_admin_password
│   └── wp_user_password
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/50-server.cnf
        │   └── tools/entrypoint.sh
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/nginx.conf
        │   └── tools/entrypoint.sh
        └── wordpress/
            ├── Dockerfile
            ├── conf/www.conf
            └── tools/entrypoint.sh
```

## 4. Configuration from scratch

### 4.1 Generate `.env`

Run:

```bash
make env
```

The Makefile creates `srcs/.env` from interactive input.

Generated values include:

```text
LOGIN
DOMAIN_NAME
DB_HOST
DB_PORT
DB_NAME
DB_USER
WP_TITLE
WP_ADMIN_USER
WP_ADMIN_EMAIL
WP_USER
WP_USER_EMAIL
```

The database host is the Compose service name `mariadb`; no host IP is required for internal service communication.

### 4.2 Generate secrets

Run:

```bash
make secrets
```

The Makefile creates:

```text
secrets/db_root_password
secrets/db_password
secrets/wp_admin_password
secrets/wp_user_password
```

Permissions are set to:

```text
secrets/       700
*_password     600
```

Compose mounts the relevant secret into each container at `/run/secrets/`.

The project deliberately keeps passwords outside `srcs/.env`.

## 5. Docker Compose architecture

`srcs/docker-compose.yml` defines three services.

### MariaDB service

```text
build: ./requirements/mariadb
image: mariadb
container_name: mariadb
```

It:

- uses the custom MariaDB Dockerfile;
- joins the `inception` network;
- mounts `mariadb_data` at `/var/lib/mysql`;
- receives `.env` configuration;
- receives `db_root_password` and `db_password` secrets;
- restarts unless explicitly stopped.

### WordPress service

```text
build: ./requirements/wordpress
image: wordpress
container_name: wordpress
```

It:

- uses the custom WordPress/PHP-FPM Dockerfile;
- joins the `inception` network;
- mounts `wordpress_data` at `/var/www/html`;
- receives `.env` configuration;
- receives the database, administrator and regular-user passwords as secrets;
- depends on the MariaDB service.

`depends_on` controls Compose startup ordering but is not itself a database readiness check. The WordPress entrypoint therefore explicitly waits until MariaDB accepts a query.

### NGINX service

```text
build: ./requirements/nginx
image: nginx
container_name: nginx
```

It:

- uses the custom NGINX Dockerfile;
- joins the `inception` network;
- publishes only `443:443`;
- mounts the WordPress data read-only at `/var/www/html`;
- receives `.env` configuration;
- depends on WordPress.

## 6. Docker network

The Compose file creates a dedicated bridge network:

```yaml
networks:
  inception:
    name: inception
    driver: bridge
```

Docker's embedded DNS resolves service names automatically.

The important internal endpoints are:

```text
wordpress:9000
mariadb:3306
```

No MariaDB or PHP-FPM host port is published.

## 7. Persistent storage

The Compose file defines:

```text
mariadb_data
wordpress_data
```

with host-backed locations:

```text
/home/${LOGIN}/data/mariadb
/home/${LOGIN}/data/wordpress
```

The Makefile creates these directories through:

```bash
make prepare
```

`build` and `up` depend on `prepare`, so normal startup prepares them automatically.

### Persistence model

- MariaDB files remain in `/home/${LOGIN}/data/mariadb`.
- WordPress files remain in `/home/${LOGIN}/data/wordpress`.
- Container removal does not intentionally remove those host directories.
- `make fclean-data` is the explicit destructive data-cleanup operation.

## 8. MariaDB implementation

### Dockerfile

The MariaDB image starts from:

```dockerfile
FROM debian:bookworm
```

It installs:

```text
mariadb-server
mariadb-client
```

and copies:

```text
conf/50-server.cnf
/usr/local/bin/entrypoint.sh
```

### MariaDB configuration

`50-server.cnf` configures:

- user: `mysql`
- address: `0.0.0.0`
- port: `3306`
- data directory: `/var/lib/mysql`
- UTF-8 `utf8mb4`
- `skip-name-resolve`

### Entry point lifecycle

`mariadb/tools/entrypoint.sh`:

1. Reads the root and database passwords from `/run/secrets/`.
2. Creates `/run/mysqld` and fixes ownership.
3. Initializes the MariaDB data directory if needed.
4. Starts a temporary MariaDB server with networking disabled.
5. Waits for the temporary server to become ready.
6. Sets the root password.
7. Creates the WordPress database.
8. Creates/updates the WordPress database user.
9. Grants the user privileges on the WordPress database.
10. Shuts down the temporary server.
11. Creates an initialization marker:

```text
/var/lib/mysql/.${DB_NAME}_initialized
```

12. Starts the real MariaDB server in the foreground with `exec mariadbd ...`.

The marker prevents the initialization sequence from being repeated on every container restart.

## 9. WordPress implementation

### Dockerfile

The WordPress image also starts from:

```dockerfile
FROM debian:bookworm
```

It installs PHP-FPM 8.2, the required PHP extensions, `curl`, CA certificates and the MariaDB client.

The PHP-FPM pool listens on:

```text
0.0.0.0:9000
```

### Entry point lifecycle

`wordpress/tools/entrypoint.sh`:

1. Reads the database, WordPress-admin and WordPress-user passwords from secrets.
2. Creates `/run/php`.
3. Sets WordPress ownership to `www-data`.
4. Downloads the WordPress archive if `wp-load.php` is missing.
5. Waits for MariaDB with a real SQL query.
6. Downloads WP-CLI.
7. Generates `wp-config.php` with `wp config create`.
8. Installs WordPress with `wp core install`.
9. Creates the configured regular user with the `author` role.
10. Creates:

```text
/var/www/html/.wp_installed
```

11. Starts PHP-FPM in the foreground.

The initialization marker prevents WordPress installation from being repeated after the application data persists.

## 10. NGINX implementation

### Dockerfile

The NGINX image starts from Debian Bookworm and installs:

```text
nginx
openssl
```

### HTTPS

The NGINX entrypoint creates `/etc/nginx/ssl` and generates a local self-signed RSA certificate if the key/certificate do not already exist.

The certificate uses:

```text
CN=${DOMAIN_NAME}
subjectAltName=DNS:${DOMAIN_NAME}
```

and is valid for 365 days.

The private key is restricted to mode `600`.

### NGINX routing

The NGINX configuration:

- listens on `443 ssl`;
- uses `/var/www/html` as the WordPress document root;
- routes normal requests through WordPress's `index.php` fallback;
- verifies PHP files exist before passing them to PHP-FPM;
- sets `HTTPS on` for FastCGI;
- sends PHP requests to `wordpress:9000`;
- denies access to hidden files.

The entrypoint validates the configuration with:

```bash
nginx -t
```

and finally runs:

```bash
exec nginx -g "daemon off;"
```

## 11. Makefile reference

### Configuration

```bash
make env
make secrets
make prepare
```

### Build and launch

```bash
make build
make up
```

`build` runs:

```bash
docker compose -f srcs/docker-compose.yml build --pull
```

`up` runs:

```bash
docker compose -f srcs/docker-compose.yml up -d --build
```

### Lifecycle

```bash
make down
make stop
make start
make restart
```

### Status and logs

```bash
make status
make logs
make logs-nginx
make logs-wordpress
make logs-mariadb
```

### Shell access

```bash
make shell-nginx
make shell-wordpress
make shell-mariadb
```

### Domain mapping

```bash
make hosts
```

This uses:

```bash
hostname -I | awk '{print $1}'
```

to select the first host IP, removes an existing `${LOGIN}.42.fr` line from `/etc/hosts`, then writes the new mapping with `sudo tee`.

### Cleanup

```bash
make clean
make fclean
make fclean-data
make re
```

The cleanup levels are deliberately different:

| Target | Containers | Compose volumes | Project images | Host persistent data |
|---|---|---|---|---|
| `clean` | Removed | Preserved | Preserved | Preserved |
| `fclean` | Removed | Removed | Removed | Preserved |
| `fclean-data` | No general cleanup | No general cleanup | No general cleanup | **Deleted** |
| `re` | Full `fclean`, then startup | Removed | Removed | Preserved |

## 12. Development and debugging

### Check Compose state

```bash
docker compose -f srcs/docker-compose.yml ps
```

### Inspect containers

```bash
docker inspect nginx
docker inspect wordpress
docker inspect mariadb
```

### Inspect the network

```bash
docker network inspect inception
```

### Inspect volumes

```bash
docker volume inspect mariadb_data
docker volume inspect wordpress_data
```

### Check domain mapping

```bash
grep "${LOGIN}.42.fr" /etc/hosts
```

### Check HTTPS

```bash
curl -kI "https://${LOGIN}.42.fr"
```

`-k` is appropriate for the locally generated self-signed certificate.

## 13. Typical development workflow

Fresh setup:

```bash
make env
make secrets
make hosts
make up
make status
```

After changing a Dockerfile or service configuration:

```bash
make build
make up
```

For a clean Docker rebuild while preserving persistent host data:

```bash
make fclean
make up
```

For a completely fresh WordPress/MariaDB state:

```bash
make fclean-data
make up
```

Use the last operation carefully because it deletes persistent application and database data.

## 14. Security considerations

- Passwords are generated separately from `.env` and mounted through Docker secrets.
- The secrets directory and secret files use restrictive permissions.
- NGINX sees the WordPress volume as read-only.
- MariaDB and PHP-FPM are not published to the host.
- Only HTTPS port `443` is exposed.
- NGINX denies hidden files.
- TLS uses TLS 1.2 and TLS 1.3.
- The certificate contains the configured domain as a SAN.
- Service entrypoints run the final service process in the foreground.

## 15. Git hygiene

Generated credentials should not be committed. A suitable `.gitignore` should contain at least:

```gitignore
srcs/.env
secrets/*
```

If the empty `secrets/` directory must remain represented in Git, keep a `.gitkeep` file while ignoring the generated secret files.

Never commit:

- real passwords;
- private TLS keys;
- generated certificates if they are intended to be runtime-generated;
- database contents;
- personal credentials.
