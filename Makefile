SHELL := /bin/bash
COMPOSE := docker compose
WEB_PORT ?= $(shell grep -E '^WEB_PORT=' .env 2>/dev/null | cut -d= -f2 || echo 8080)

.DEFAULT_GOAL := help
.PHONY: help setup up down restart build rebuild logs ps seed migrate migration db-shell api-shell mobile-web mobile-run mobile-test mobile-apk \
        install dev-db dev-api dev-web test test-api test-web lint clean

help: ## Lista os comandos disponíveis
	@awk 'BEGIN {FS = ":.*##"; printf "\nFlenity — comandos\n\n"} /^[a-zA-Z_-]+:.*##/ { printf "  \033[38;5;209m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo

# ---------------------------------------------------------------- Docker

setup: ## Cria o .env com segredos aleatórios (não sobrescreve um existente)
	@if [ -f .env ]; then echo ".env já existe — mantido."; else \
		sed -e "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$$(openssl rand -hex 16)/" \
		    -e "s/^JWT_SECRET=.*/JWT_SECRET=$$(openssl rand -hex 32)/" .env.example > .env; \
		echo ".env criado com segredos gerados."; fi

up: setup ## Sobe tudo (banco, API com migrações, web) em segundo plano
	$(COMPOSE) up -d --build --wait
	@echo -e "\n  Flenity em \033[1mhttp://localhost:$(WEB_PORT)\033[0m\n  Dados de demonstração: make seed\n"

down: ## Para os containers (mantém os dados)
	$(COMPOSE) down

restart: ## Reinicia os containers
	$(COMPOSE) restart

build: ## Builda as imagens
	$(COMPOSE) build

rebuild: ## Builda sem cache e sobe de novo
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d --wait

logs: ## Acompanha os logs (ex.: make logs s=api)
	$(COMPOSE) logs -f --tail=100 $(s)

ps: ## Status dos containers
	$(COMPOSE) ps

seed: ## Popula a academia de demonstração (APAGA e recria a academia demo)
	$(COMPOSE) --profile tools run --rm --build seed
	@echo "Login: admin@flenity.com / combate123"

migrate: ## Aplica migrações pendentes no banco do Docker
	$(COMPOSE) exec api npx prisma migrate deploy

db-shell: ## Abre o psql no banco
	$(COMPOSE) exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

api-shell: ## Abre um shell no container da API
	$(COMPOSE) exec api sh

clean: ## Remove containers, imagens do projeto e o VOLUME DO BANCO (pede confirmação)
	@read -p "Isso apaga todos os dados do banco. Digite 'sim' para confirmar: " ans && [ "$$ans" = "sim" ]
	$(COMPOSE) --profile tools down -v --rmi local

# ---------------------------------------------------------------- Desenvolvimento local

install: ## Instala dependências da API e da web
	cd api && npm ci
	cd web && npm ci

dev-db: setup ## Sobe só o Postgres (para rodar API/web fora do Docker)
	$(COMPOSE) up -d --wait postgres

dev-api: ## Roda a API em modo watch (requer api/.env)
	cd api && npx prisma migrate dev && npm run dev

dev-web: ## Roda a web com Vite (proxy para a API em :3000)
	cd web && npm run dev

migration: ## Cria uma nova migração (ex.: make migration name=add_exams)
	@test -n "$(name)" || (echo "Uso: make migration name=<nome>" && exit 1)
	cd api && npx prisma migrate dev --name $(name)

# ---------------------------------------------------------------- Qualidade

test: test-api test-web mobile-test ## Roda todos os testes (API, web e app)

test-api: ## Testes da API (Jest)
	cd api && npm test

test-web: ## Testes da web (Vitest)
	cd web && npm test

lint: ## Typecheck da API e lint da web
	cd api && npx tsc -p tsconfig.json --noEmit
	cd web && npx eslint src

# ---------------------------------------------------------------- App mobile (Flutter)
# API_URL: endereço da API visto pelo aparelho. Emulador Android: http://10.0.2.2:8080/api
API_URL ?= http://localhost:8080/api
# Usa o flutter do PATH; se não houver, tenta a instalação padrão em ~/flutter.
FLUTTER ?= $(or $(shell command -v flutter 2>/dev/null),$(wildcard $(HOME)/flutter/bin/flutter),flutter)

MOBILE_WEB_PORT ?= $(or $(shell grep -E '^MOBILE_WEB_PORT=' .env 2>/dev/null | cut -d= -f2),5180)

mobile-web: ## Serve o app no navegador em http://localhost:5180 (não abre o Chrome automaticamente)
	@echo -e "\n  Abra \033[1mhttp://localhost:$(MOBILE_WEB_PORT)\033[0m no navegador (r = reload, q = sair)\n"
	cd mobile && $(FLUTTER) run -d web-server --web-hostname localhost --web-port $(MOBILE_WEB_PORT) --dart-define=API_URL=$(API_URL)

mobile-run: ## Roda o app Flutter (ex.: make mobile-run API_URL=http://10.0.2.2:8080/api)
	cd mobile && $(FLUTTER) run --dart-define=API_URL=$(API_URL)

mobile-test: ## Testes e análise estática do app
	cd mobile && $(FLUTTER) analyze && $(FLUTTER) test

mobile-apk: ## Gera o APK de release (ex.: make mobile-apk API_URL=https://academia.com/api)
	cd mobile && $(FLUTTER) build apk --release --dart-define=API_URL=$(API_URL)
	@echo "APK: mobile/build/app/outputs/flutter-apk/app-release.apk"
