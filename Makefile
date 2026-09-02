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

clean:
	$(COMPOSE) down --remove-orphans
