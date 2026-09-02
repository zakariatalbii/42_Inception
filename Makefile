ENV_FILE = srcs/.env

LOGIN ?= $(shell grep '^LOGIN=' $(ENV_FILE) | cut -d= -f2 | tr -d '"')

DATA_DIR = /home/$(LOGIN)/data

COMPOSE = docker compose -f srcs/docker-compose.yml

all: up

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
	$(COMPOSE) exec nginx sh

shell-wordpress:
	$(COMPOSE) exec wordpress sh

shell-mariadb:
	$(COMPOSE) exec mariadb sh

hosts:
	@IP=$$(hostname -I | awk '{print $$1}'); \
	grep -qE "[[:space:]]$(LOGIN)\.42\.fr([[:space:]]|$$)" /etc/hosts 2> /dev/null || \
	echo "$$IP $(LOGIN).42.fr" | sudo tee -a /etc/hosts > /dev/null
	@echo "Configured $(LOGIN).42.fr"

clean:
	$(COMPOSE) down --remove-orphans

fclean:
	$(COMPOSE) down -v --remove-orphans
	docker image rm -f nginx wordpress mariadb 2> /dev/null || true
	@echo "Persistent host data was NOT deleted from $(DATA_DIR)."

fclean-data:
	@echo "WARNING: this deletes the two persistent Inception data directories."
	@read -p "Continue? [y/N] " confirm; [ "$$confirm" = "y" ] || exit 1
	sudo rm -rf $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

re: fclean all
