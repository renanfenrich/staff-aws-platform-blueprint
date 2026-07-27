SHELL := /bin/sh
TF_DIR := infra/terraform
IMAGE := staff-aws-platform-blueprint-api:local

.PHONY: help setup run lint typecheck test security container docs-check workflow-lint \
	tf-init tf-format tf-format-check tf-validate tf-plan tf-test validate

help:
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "%-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Install pinned dependencies and initialize Terraform
	npm ci
	$(MAKE) tf-init

run: ## Build and run the API locally
	npm run build
	npm start

lint: ## Check source and configuration formatting and lint rules
	npm run lint

typecheck: ## Type-check without emitting files
	npm run typecheck

test: ## Build and run unit/integration tests
	npm test

security: container ## Run dependency, secret, filesystem, Terraform, and image scans
	SCAN_IMAGE_REF=$(IMAGE) ./scripts/security.sh

container: ## Build the pinned, non-root application image
	docker build --tag $(IMAGE) .

docs-check: ## Lint Markdown documentation
	npm run docs:check

workflow-lint: ## Validate GitHub Actions workflow syntax
	docker run --rm --volume "$(CURDIR):/repo" --workdir /repo \
		rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667

tf-init: ## Initialize Terraform without a remote backend
	terraform -chdir=$(TF_DIR) init -backend=false -input=false

tf-format: ## Format Terraform files
	terraform fmt -recursive $(TF_DIR)

tf-format-check: ## Check Terraform formatting
	terraform fmt -check -recursive $(TF_DIR)

tf-validate: tf-init ## Validate Terraform configuration
	terraform -chdir=$(TF_DIR) validate

tf-plan: tf-init ## Prove the disabled plan contains zero AWS resource changes
	./scripts/tf-plan.sh

tf-test: tf-init ## Test the enabled runtime graph with a mock AWS provider
	terraform -chdir=$(TF_DIR) test

validate: lint typecheck test docs-check workflow-lint tf-format-check tf-validate tf-plan tf-test ## Run the local quality gate
