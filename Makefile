.DEFAULT_GOAL := help
SHELL := /bin/bash

.PHONY: help
help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: setup
setup: ## Installe les outils Python et les collections Ansible
	pip install -r requirements-dev.txt
	cd ansible && ansible-galaxy collection install -r requirements.yml -p collections

.PHONY: lint
lint: ## Lance tous les linters (comme la CI)
	terraform fmt -check -recursive terraform
	cd ansible && ansible-lint --profile production
	shellcheck scripts/*.sh
	hadolint docker/wordpress/Dockerfile
	actionlint

.PHONY: test
test: ## Lance les tests unitaires
	pytest -v tests

.PHONY: scan
scan: ## Scan Trivy local de la configuration et de l'image
	trivy config --severity HIGH,CRITICAL --exit-code 1 --ignorefile .trivyignore.yaml .
	docker build -t wordpress-hardened:local docker/wordpress
	trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --ignorefile .trivyignore.yaml wordpress-hardened:local

.PHONY: bootstrap
bootstrap: ## Crée le socle Azure (state, identités OIDC) — une seule fois
	terraform -chdir=terraform/bootstrap init
	terraform -chdir=terraform/bootstrap apply

.PHONY: tunnel
tunnel: ## Tunnel SSH vers Prometheus (9090) et Alertmanager (9093) : make tunnel HOST=<ip>
	@test -n "$(HOST)" || (echo "Usage : make tunnel HOST=<ip>" && exit 1)
	ssh -N -L 9090:127.0.0.1:9090 -L 9093:127.0.0.1:9093 deploy@$(HOST)
