.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

# MODE=local (default) or MODE=prod (adds compose.prod.yaml)
MODE ?= local
ifeq ($(MODE),prod)
COMPOSE ?= docker compose -f compose.yaml -f compose.prod.yaml
else
COMPOSE ?= docker compose
endif

# Optional compose profiles, e.g. `make up PROFILES=tools`
ifdef PROFILES
export COMPOSE_PROFILES := $(PROFILES)
endif

# Bind-mounted files are written with the host user's IDs.
HOST_UID ?= $(shell id -u)
HOST_GID ?= $(shell id -g)
export HOST_UID HOST_GID COMPOSE MODE

# Allocate a TTY only when there is one (keeps targets usable in CI/pipes).
TTY := $(shell [ -t 0 ] || echo -T)

SERVICE ?=
ARGS ?=

# Pinned linter images (also used by CI)
HADOLINT   := hadolint/hadolint:v2.15.1
SHELLCHECK := koalaman/shellcheck:v0.11.0
YAMLLINT   := pipelinecomponents/yamllint:0.35.27
VARNISH    := varnish:9.0

ENV_FILE := $(if $(wildcard .env),.env,.env.example)

##@ Setup

.PHONY: help
help: ## Show this help
	@awk 'BEGIN { FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m [MODE=prod] [PROFILES=tools]\n" } \
		/^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

.PHONY: init
init: ## Create .env (random secrets), local certs and the Bedrock project in app/
	@scripts/init.sh

.PHONY: certs
certs: ## (Re)generate the local TLS certificate (mkcert, openssl fallback)
	@scripts/generate-certs.sh

.PHONY: install
install: ## Install WordPress and enable the Redis object cache
	@scripts/install-wordpress.sh

##@ Lifecycle

.PHONY: up
up: ## Build and start the stack, wait until every service is healthy
	$(COMPOSE) up -d --build --wait

.PHONY: down
down: ## Stop the stack (keeps volumes)
	$(COMPOSE) down --remove-orphans

.PHONY: restart
restart: ## Restart all services, or one with SERVICE=name
	$(COMPOSE) restart $(SERVICE)

.PHONY: ps
ps: ## Show service status
	$(COMPOSE) ps

.PHONY: logs
logs: ## Follow logs (all services, or SERVICE=name)
	$(COMPOSE) logs -f --tail=100 $(SERVICE)

.PHONY: sh
sh: ## Open a shell in a service (default SERVICE=php)
	$(COMPOSE) exec $(or $(SERVICE),php) sh

.PHONY: destroy
destroy: ## Stop the stack and delete its volumes (database included)
	$(COMPOSE) --profile cli --profile tools down --volumes --remove-orphans

##@ WordPress

.PHONY: wp
wp: ## Run wp-cli, e.g. make wp ARGS="plugin list"
	$(COMPOSE) run --rm $(TTY) wp-cli $(ARGS)

.PHONY: composer
composer: ## Run Composer in app/, e.g. make composer ARGS="require wp-plugin/query-monitor"
	$(COMPOSE) run --rm --no-deps $(TTY) composer $(ARGS)

.PHONY: db-export
db-export: ## Dump the database (FILE=backups/db.sql.gz, default: timestamped)
	@scripts/db.sh export $(FILE)

.PHONY: db-import
db-import: ## Import a dump, FILE=path/to/dump.sql[.gz]
	@scripts/db.sh import $(FILE)

.PHONY: backup
backup: ## Back up database + uploads to backups/<timestamp>/
	@scripts/backup.sh create

.PHONY: restore
restore: ## Restore a backup, BACKUP=backups/<timestamp>
	@scripts/backup.sh restore $(BACKUP)

.PHONY: purge-cache
purge-cache: ## Invalidate everything in Varnish and flush the Redis object cache
	$(COMPOSE) exec -T varnish varnishadm 'ban req.url ~ .'
	$(COMPOSE) exec -T redis redis-cli FLUSHDB

##@ Quality

.PHONY: config
config: ## Validate the compose files for both modes
	docker compose --env-file $(ENV_FILE) -f compose.yaml config --quiet
	docker compose --env-file $(ENV_FILE) -f compose.yaml -f compose.prod.yaml config --quiet
	@echo "compose config OK (local + prod, env: $(ENV_FILE))"

.PHONY: lint
lint: ## Run hadolint, shellcheck and yamllint (via Docker)
	docker run --rm -i -v "$(CURDIR)/.hadolint.yaml:/.config/hadolint.yaml:ro" $(HADOLINT) < docker/php/Dockerfile
	docker run --rm -v "$(CURDIR):/mnt:ro" -w /mnt $(SHELLCHECK) -x scripts/*.sh
	docker run --rm -v "$(CURDIR):/code:ro" -w /code $(YAMLLINT) yamllint --strict .
	@echo "lint OK"

.PHONY: test-vcl
test-vcl: ## Compile the VCL and run the varnishtest cases
	docker run --rm --add-host nginx:127.0.0.1 -v "$(CURDIR)/docker/varnish:/etc/varnish:ro" \
		--entrypoint sh $(VARNISH) -c \
		'out=$$(varnishd -C -f /etc/varnish/default.vcl 2>&1) || { echo "$$out" | tail -n 30; exit 1; }'
	docker run --rm -v "$(CURDIR)/docker/varnish:/etc/varnish:ro" \
		--entrypoint sh $(VARNISH) -c 'varnishtest -q /etc/varnish/tests/*.vtc'
	@echo "VCL OK"

.PHONY: smoke
smoke: ## End-to-end test against the running local stack
	@scripts/smoke-test.sh
