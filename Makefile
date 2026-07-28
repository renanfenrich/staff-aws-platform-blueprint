SHELL := /bin/sh
TF_DIR := infra/terraform
BOOTSTRAP_DIR := infra/bootstrap
IMAGE := staff-aws-platform-blueprint-api:local
IMAGE_EVIDENCE_DIR := .artifacts/image

.PHONY: help setup run lint typecheck test security container docs-check workflow-lint \
	aws-foundation-check bootstrap-init bootstrap-format-check bootstrap-validate \
	bootstrap-plan-disabled bootstrap-test tf-init tf-init-local tf-init-remote \
	tf-format tf-format-check tf-validate tf-plan tf-test image-build image-scan \
	image-sbom image-publication-check validate

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
	docker build --platform linux/amd64 --provenance=false --sbom=false --tag $(IMAGE) .

image-build: container ## Build the local X86_64 image without publishing

image-scan: ## Scan an existing local image with the publication policy
	./scripts/image-scan.sh $(IMAGE) $(IMAGE_EVIDENCE_DIR)/trivy-results.json

image-sbom: ## Generate an SPDX JSON SBOM from an existing local image
	./scripts/image-sbom.sh $(IMAGE) $(IMAGE_EVIDENCE_DIR)/sbom.spdx.json

image-publication-check: ## Statically validate the manual publication boundary
	node scripts/validate-image-publication.mjs

docs-check: ## Lint Markdown documentation
	npm run docs:check

workflow-lint: ## Validate GitHub Actions workflow syntax
	docker run --rm --volume "$(CURDIR):/repo" --workdir /repo \
		rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667

aws-foundation-check: ## Statically validate the backend, OIDC trust, and smoke workflow
	node scripts/validate-aws-foundation.mjs

bootstrap-init: ## Initialize the bootstrap root with local state
	terraform -chdir=$(BOOTSTRAP_DIR) init -backend=false -input=false

bootstrap-format-check: ## Check bootstrap Terraform formatting
	terraform fmt -check -recursive $(BOOTSTRAP_DIR)

bootstrap-validate: bootstrap-init ## Validate the credential-free bootstrap root
	terraform -chdir=$(BOOTSTRAP_DIR) validate

bootstrap-plan-disabled: bootstrap-init ## Prove the disabled bootstrap plan has zero changes
	./scripts/bootstrap-plan.sh

bootstrap-test: bootstrap-init ## Test the enabled bootstrap graph with a mock AWS provider
	terraform -chdir=$(BOOTSTRAP_DIR) test

tf-init: tf-init-local ## Initialize Terraform without a remote backend

tf-init-local: ## Initialize runtime Terraform without a remote backend
	terraform -chdir=$(TF_DIR) init -backend=false -input=false -reconfigure

tf-init-remote: ## Initialize runtime Terraform with an explicit partial backend config
	@test -n "$(BACKEND_CONFIG)" || \
		{ echo "BACKEND_CONFIG must name an explicit backend configuration file." >&2; exit 1; }
	@test -f "$(BACKEND_CONFIG)" || \
		{ echo "Backend configuration file not found: $(BACKEND_CONFIG)" >&2; exit 1; }
	terraform -chdir=$(TF_DIR) init -input=false -reconfigure \
		-backend-config="$(abspath $(BACKEND_CONFIG))"

tf-format: ## Format Terraform files
	terraform fmt -recursive $(TF_DIR)

tf-format-check: ## Check Terraform formatting
	terraform fmt -check -recursive $(TF_DIR)

tf-validate: tf-init-local ## Validate Terraform configuration
	terraform -chdir=$(TF_DIR) validate

tf-plan: ## Prove the disabled plan contains zero AWS resource changes
	./scripts/tf-plan.sh

tf-test: tf-init-local ## Test the enabled runtime graph with a mock AWS provider
	terraform -chdir=$(TF_DIR) test

validate: lint typecheck test docs-check workflow-lint aws-foundation-check \
	image-publication-check \
	tf-format-check tf-validate tf-plan tf-test bootstrap-format-check \
	bootstrap-validate bootstrap-plan-disabled bootstrap-test ## Run the local quality gate
