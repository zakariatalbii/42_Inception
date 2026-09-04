SHELL := /bin/bash

ENV_FILE = srcs/.env

LOGIN = $(shell grep '^LOGIN=' $(ENV_FILE) | cut -d= -f2 | tr -d '"')

DATA_DIR = /home/$(LOGIN)/data

COMPOSE = docker compose -f srcs/docker-compose.yml

all: up

env:
	@read -p "LOGIN = " LOGIN; \
	read -p "WP_TITLE = " WP_TITLE; \
	read -p "WP_ADMIN_USER = " WP_ADMIN_USER; \
	read -p "WP_ADMIN_EMAIL = " WP_ADMIN_EMAIL; \
	read -p "WP_USER = " WP_USER; \
	read -p "WP_USER_EMAIL = " WP_USER_EMAIL; \
	if [ -z "$$LOGIN" ] || [ -z "$$WP_TITLE" ] || [ -z "$$WP_ADMIN_USER" ] || \
	   [ -z "$$WP_ADMIN_EMAIL" ] || [ -z "$$WP_USER" ] || [ -z "$$WP_USER_EMAIL" ]; then \
		echo "Error: all fields are required." >&2; \
		exit 1; \
	fi; \
	{ \
		echo "LOGIN=\"$$LOGIN\""; \
		echo "DOMAIN_NAME=\"$${LOGIN}.42.fr\""; \
		echo "DB_HOST=\"mariadb\""; \
		echo "DB_PORT=\"3306\""; \
		echo "DB_NAME=\"wordpress\""; \
		echo "DB_USER=\"wpuser\""; \
		echo "WP_TITLE=\"$$WP_TITLE\""; \
		echo "WP_ADMIN_USER=\"$$WP_ADMIN_USER\""; \
		echo "WP_ADMIN_EMAIL=\"$$WP_ADMIN_EMAIL\""; \
		echo "WP_USER=\"$$WP_USER\""; \
		echo "WP_USER_EMAIL=\"$$WP_USER_EMAIL\""; \
	} > srcs/.env; \
	echo "srcs/.env generated successfully."

secrets:
	@read -s -p "DB root password: " DB_ROOT_PASSWORD; echo; \
	read -s -p "DB password: " DB_PASSWORD; echo; \
	read -s -p "WordPress admin password: " WP_ADMIN_PASSWORD; echo; \
	read -s -p "WordPress user password: " WP_USER_PASSWORD; echo; \
	if [ -z "$$DB_ROOT_PASSWORD" ] || [ -z "$$DB_PASSWORD" ] || \
	   [ -z "$$WP_ADMIN_PASSWORD" ] || [ -z "$$WP_USER_PASSWORD" ]; then \
		echo "Error: all passwords are required." >&2; \
		exit 1; \
	fi; \
	mkdir -p secrets; \
	chmod 700 secrets; \
	touch secrets/.gitkeep; \
	printf '%s' "$$DB_ROOT_PASSWORD" > secrets/db_root_password; \
	printf '%s' "$$DB_PASSWORD" > secrets/db_password; \
	printf '%s' "$$WP_ADMIN_PASSWORD" > secrets/wp_admin_password; \
	printf '%s' "$$WP_USER_PASSWORD" > secrets/wp_user_password; \
	chmod 600 secrets/*_password; \
	echo "Docker secrets generated successfully."

prepare:
	@mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	@chmod 700 secrets 2> /dev/null || true

build: prepare
	$(COMPOSE) build --pull

up: prepare
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

restart:
	$(COMPOSE) restart

status:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

logs-nginx:
	$(COMPOSE) logs -f nginx

logs-wordpress:
	$(COMPOSE) logs -f wordpress

logs-mariadb:
	$(COMPOSE) logs -f mariadb

shell-nginx:
	$(COMPOSE) exec nginx bash

shell-wordpress:
	$(COMPOSE) exec wordpress bash

shell-mariadb:
	$(COMPOSE) exec mariadb bash

hosts:
	@IP=$$(hostname -I | awk '{print $$1}'); \
	sudo sed -i "/[[:space:]]$(LOGIN)\.42\.fr\([[:space:]]\|$$\)/d" /etc/hosts; \
	echo "$$IP $(LOGIN).42.fr" | sudo tee -a /etc/hosts > /dev/null; \
	echo "Configured $(LOGIN).42.fr -> $$IP"

clean:
	$(COMPOSE) down --remove-orphans
	@echo "Containers and networks removed. Persistent data preserved."

fclean:
	$(COMPOSE) down -v --remove-orphans
	docker image rm -f nginx wordpress mariadb 2> /dev/null || true
	@echo "Full cleanup completed. Persistent host data was preserved in $(DATA_DIR)."

fclean-data:
	@echo "WARNING: this deletes the two persistent Inception data directories."
	@read -p "Continue? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		sudo rm -rf $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress; \
		echo "Persistent data deleted."; \
	else \
		echo "Cancelled."; \
	fi

re: fclean all

.PHONY: all env secrets prepare build up down stop start restart \
		status logs logs-nginx logs-wordpress logs-mariadb \
        shell-nginx shell-wordpress shell-mariadb hosts \
        clean fclean fclean-data re
