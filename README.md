*This project has been created as part of the 42 curriculum by zatalbi.*

# Inception

## Description

Inception is a 42 School system-administration project whose goal is to build a small, secure and reproducible web infrastructure using Docker and Docker Compose.

The project is composed of three custom Docker images, each running one main service:

- **NGINX**: the HTTPS entry point and web server. It listens on port `443`, serves WordPress files and forwards PHP requests to PHP-FPM.
- **WordPress + PHP-FPM**: provides the WordPress application and executes PHP requests.
- **MariaDB**: provides the relational database used by WordPress.

The services run in separate containers and communicate through a dedicated Docker bridge network. Only NGINX publishes a port to the host.

### Project architecture

```text
                         Host
                           |
                       HTTPS :443
                           |
                    +------+------+
                    |    NGINX    |
                    |    HTTPS    |
                    +------+------+
                           |
                      FastCGI :9000
                           |
                 +---------v----------+
                 | WordPress / PHP-FPM|
                 +---------+----------+
                           |
                       MariaDB :3306
                           |
                 +---------v----------+
                 |      MariaDB       |
                 +---------------------+

        All three containers are connected to the
             dedicated "inception" bridge network.
```

### Project sources

The repository is structured as follows:

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
├── secrets/
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

The three images are built from `debian:bookworm` rather than using ready-made application images. The MariaDB, NGINX and WordPress images contain only the software required by their respective services.

WordPress and WP-CLI are downloaded during the WordPress container's first initialization. NGINX generates a local self-signed TLS certificate when required. MariaDB initializes its database only when its persistent data directory has not already been initialized.

### Main design choices

- **One service per container**: NGINX, WordPress/PHP-FPM and MariaDB have separate responsibilities and separate containers.
- **Custom images**: the project builds each service from Debian Bookworm Dockerfiles.
- **Docker Compose**: `srcs/docker-compose.yml` defines services, networking, secrets, dependencies and persistent storage.
- **Dedicated bridge network**: services use Docker DNS and service names such as `wordpress` and `mariadb` for internal communication.
- **HTTPS only at the host boundary**: NGINX publishes `443:443`; MariaDB and PHP-FPM are internal services.
- **Secrets for passwords**: passwords are generated into files and mounted by Compose under `/run/secrets/` instead of being placed in `srcs/.env`.
- **Environment variables for non-secret configuration**: values such as the login, domain, database name and WordPress usernames are stored in `srcs/.env`.
- **Persistent storage**: MariaDB data and WordPress files are stored under `/home/${LOGIN}/data/` so containers can be recreated without intentionally deleting application data.
- **Foreground processes**: the entrypoints finish by using `exec` to run the main service process in the foreground, allowing Docker to track the service correctly.

## Virtual Machines vs Docker

| Virtual Machines | Docker containers |
|---|---|
| Virtualize a complete guest operating system. | Isolate application processes while sharing the host kernel. |
| Generally require more disk space and memory. | Usually lighter and faster to start. |
| Each VM normally contains its own OS. | Images can contain only the required userspace and software. |
| Useful when different kernels or complete OS environments are required. | Well suited to packaging separate application services. |
| Stronger isolation at the virtual-machine boundary. | Process-level isolation with Linux namespaces, cgroups and container security mechanisms. |

Docker is appropriate for this project because the infrastructure consists of independent application services that need reproducible environments without running three complete operating systems.

## Secrets vs Environment Variables

Environment variables are used for ordinary configuration, for example:

```text
DB_HOST=mariadb
DB_PORT=3306
DB_NAME=wordpress
DB_USER=wpuser
```

Passwords are handled separately through Docker secrets:

```text
/run/secrets/db_root_password
/run/secrets/db_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
```

This separation prevents application passwords from being part of the normal `.env` configuration. The entrypoint scripts read the secret files directly.

Environment variables are convenient for configuration but are not a dedicated secret-management mechanism. Secrets provide a more appropriate interface for sensitive credentials.

## Docker Network vs Host Network

The project uses a dedicated Docker `bridge` network named `inception`.

Internal communication is therefore performed using Docker service names:

```text
NGINX      -> wordpress:9000
WordPress  -> mariadb:3306
```

The database and PHP-FPM ports do not need to be exposed on the host. Only NGINX publishes port `443`.

With **host networking**, a container shares the host's network namespace. This reduces network isolation and makes the container directly participate in the host network. The dedicated Docker network is preferable here because it keeps internal service communication inside the Compose infrastructure.

## Docker Volumes vs Bind Mounts

A **Docker volume** is managed by Docker and can persist independently of a container. A **bind mount** maps a specific host path directly into a container.

This project defines two named Compose volumes:

```text
mariadb_data
wordpress_data
```

and configures them with Docker's local volume driver and host-backed storage:

```text
/home/${LOGIN}/data/mariadb
/home/${LOGIN}/data/wordpress
```

This gives the project explicit persistent host locations while keeping container storage disposable.

## Instructions

### Prerequisites

You need:

- Linux or a Linux VM suitable for Docker
- Docker Engine
- Docker Compose v2 (`docker compose`)
- GNU Make
- `sudo` access
- Internet access for package/image builds and first WordPress initialization

Check the tools:

```bash
docker --version
docker compose version
make --version
```

### 1. Generate the environment

From the repository root:

```bash
make env
```

The Makefile asks for the 42 login and the WordPress configuration. It generates `srcs/.env` and automatically sets the internal database values.

### 2. Generate secrets

Run:

```bash
make secrets
```

The command asks for four passwords with hidden terminal input and creates:

```text
secrets/db_root_password
secrets/db_password
secrets/wp_admin_password
secrets/wp_user_password
```

The directory is set to mode `700` and secret files to mode `600`.

### 3. Configure the local domain

Run:

```bash
make hosts
```

The target removes an existing entry for `${LOGIN}.42.fr` and adds the first IP returned by `hostname -I` to `/etc/hosts`.

### 4. Build and launch

Run:

```bash
make up
```

This prepares the persistent directories, builds the images and starts the stack in detached mode.

To build without starting:

```bash
make build
```

### 5. Access WordPress

Open:

```text
https://${LOGIN}.42.fr
```

The administration panel is:

```text
https://${LOGIN}.42.fr/wp-admin
```

NGINX uses a local self-signed certificate, so a browser certificate warning is expected unless the certificate is explicitly trusted.

### Useful Makefile commands

```text
make env              Generate srcs/.env
make secrets          Generate secret files
make prepare          Create persistent data directories
make build            Build the custom images
make up               Build and start the stack
make down             Remove Compose containers/network
make stop             Stop containers
make start            Start stopped containers
make restart          Restart containers
make status           Show service status
make logs             Follow all service logs
make logs-nginx       Follow NGINX logs
make logs-wordpress   Follow WordPress logs
make logs-mariadb     Follow MariaDB logs
make shell-nginx      Open a shell in NGINX
make shell-wordpress  Open a shell in WordPress
make shell-mariadb    Open a shell in MariaDB
make hosts            Configure ${LOGIN}.42.fr in /etc/hosts
make clean            Remove containers/network and preserve data
make fclean           Remove containers, volumes and project images; preserve host data
make fclean-data      Delete persistent MariaDB and WordPress host data
make re               Full Docker cleanup followed by startup
```

## Persistence and cleanup

Persistent data is stored at:

```text
/home/${LOGIN}/data/mariadb
/home/${LOGIN}/data/wordpress
```

Normal cleanup should use:

```bash
make clean
```

or:

```bash
make down
```

For a Docker-level cleanup while keeping host data:

```bash
make fclean
```

To deliberately remove the persistent database and WordPress data:

```bash
make fclean-data
```

The last command is destructive and asks for confirmation.

## Resources

### Official documentation and references

- Docker documentation — https://docs.docker.com/
- Docker Compose — https://docs.docker.com/compose/
- Docker networking — https://docs.docker.com/engine/network/
- Docker volumes — https://docs.docker.com/engine/storage/volumes/
- Docker secrets — https://docs.docker.com/engine/swarm/secrets/
- Dockerfile reference — https://docs.docker.com/reference/dockerfile/
- NGINX documentation — https://nginx.org/en/docs/
- MariaDB documentation — https://mariadb.com/docs/
- PHP manual — https://www.php.net/docs.php
- PHP-FPM manual — https://www.php.net/manual/en/install.fpm.php
- WordPress Developer Resources — https://developer.wordpress.org/
- WP-CLI Handbook — https://make.wordpress.org/cli/handbook/

### AI usage
AI was used as a learning aid throughout this project — mainly to understand Docker concepts (containers, networks, volumes, secrets), debug Makefile syntax and shell quoting, and review Dockerfiles/entrypoints when something wasn't starting correctly. It also helped clarify the subject's requirements (VMs vs Docker, secrets vs env vars, network vs host, volumes vs bind mounts).
