# Inception — User Documentation

## 1. What this project provides

The stack provides a WordPress website through three Docker services:

| Service | Role | Host access |
|---|---|---|
| NGINX | HTTPS web server and FastCGI gateway | `443` |
| WordPress / PHP-FPM | WordPress application and PHP execution | Internal only |
| MariaDB | WordPress database | Internal only |

The services communicate through the Docker `inception` network. Only NGINX is exposed to the host.

## 2. First-time setup

Run all commands from the repository root.

### Generate configuration

```bash
make env
```

Enter:

- your 42 login;
- WordPress site title;
- WordPress administrator username;
- WordPress administrator email;
- WordPress regular-user username;
- WordPress regular-user email.

This creates `srcs/.env`.

### Generate passwords

```bash
make secrets
```

The terminal hides password input. Four passwords are requested:

- MariaDB root password;
- MariaDB WordPress-user password;
- WordPress administrator password;
- WordPress regular-user password.

The resulting secret files are stored in `secrets/` and are mounted into the relevant containers under `/run/secrets/`.

### Configure the domain

```bash
make hosts
```

This configures `${LOGIN}.42.fr` in `/etc/hosts`.

### Start the stack

```bash
make up
```

The first startup builds the custom images and initializes MariaDB and WordPress when their persistent data does not already exist.

## 3. Accessing the website

The website is available at:

```text
https://${LOGIN}.42.fr
```

For example, with the login `darwin`:

```text
https://darwin.42.fr
```

NGINX uses a locally generated self-signed certificate. A browser may display a certificate warning. This is expected for this local development setup.

## 4. WordPress administration

The WordPress administration panel is available at:

```text
https://${LOGIN}.42.fr/wp-admin
```

Use the administrator credentials created during `make secrets` and `make env`.

## 5. Where credentials are stored

### Passwords

The four generated password files are:

```text
secrets/db_root_password
secrets/db_password
secrets/wp_admin_password
secrets/wp_user_password
```

Inside containers, the relevant secrets are available below:

```text
/run/secrets/
```

Do not publish these files or commit real passwords to Git.

### General configuration

Non-secret configuration is stored in:

```text
srcs/.env
```

It includes the login, domain, database connection values and WordPress account information, but not the passwords.

## 6. Check whether services are running

Run:

```bash
make status
```

You can also inspect the logs:

```bash
make logs
```

Or check one service at a time:

```bash
make logs-nginx
make logs-wordpress
make logs-mariadb
```

Press `Ctrl+C` to stop following the logs. This does not stop the containers.

## 7. Start, stop and restart

### Stop containers without removing them

```bash
make stop
```

### Start stopped containers

```bash
make start
```

### Restart containers

```bash
make restart
```

### Stop and remove Compose containers/network

```bash
make down
```

Persistent host data is preserved.

## 8. Container shells

For administration or troubleshooting:

```bash
make shell-nginx
make shell-wordpress
make shell-mariadb
```

Exit a container shell with:

```bash
exit
```

## 9. Persistent data

The project stores persistent data under:

```text
/home/${LOGIN}/data/mariadb
/home/${LOGIN}/data/wordpress
```

MariaDB uses the first location for database files. WordPress uses the second for the website files.

Recreating containers does not intentionally delete these directories.

## 10. Cleanup

### Normal cleanup

```bash
make clean
```

Removes the Compose containers and network while preserving persistent data.

### Full Docker cleanup

```bash
make fclean
```

Removes Compose containers, volumes and the three project images while preserving the host data directories.

### Delete persistent application data

```bash
make fclean-data
```

This asks for confirmation and then deletes the MariaDB and WordPress persistent directories. It is destructive and should only be used when a completely fresh application/database installation is required.

## 11. Troubleshooting

### The website does not load

Check service status:

```bash
make status
```

Check NGINX:

```bash
make logs-nginx
```

Check WordPress:

```bash
make logs-wordpress
```

Check MariaDB:

```bash
make logs-mariadb
```

Verify the domain mapping:

```bash
grep "${LOGIN}.42.fr" /etc/hosts
```

### WordPress cannot connect to MariaDB

The WordPress container connects to:

```text
mariadb:3306
```

Check both services:

```bash
make logs-mariadb
make logs-wordpress
```

### A completely fresh installation is required

Stop the stack and remove persistent data:

```bash
make fclean-data
```

Then start again:

```bash
make up
```

Remember that this deletes the existing WordPress files and MariaDB database.
