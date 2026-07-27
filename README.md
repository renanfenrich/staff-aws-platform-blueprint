# staff-aws-platform-blueprint

A production-oriented reference blueprint for running a small containerized
HTTP API on AWS ECS Fargate with Terraform and GitHub Actions.

> **Foundation status:** this first slice provides the application, delivery
> guardrails, Terraform contract, security checks, and architecture decisions.
> It intentionally creates no AWS resources. The core network and runtime are
> the next slice.

## What this demonstrates

- A dependency-light Node.js 24 API with health, readiness, structured logging,
  configuration validation, and graceful shutdown.
- A non-root, digest-pinned container image suitable for a read-only filesystem.
- Offline-safe Terraform validation with mandatory tag and cost-control inputs.
- SHA-pinned CI and security workflows, Dependabot, CodeQL, Gitleaks, Trivy,
  dependency review, container scanning, and SBOM generation.
- Explicit architecture, threat, cost, rollback, incident, DR, and maturity
  documentation.

## Quick start

Requirements: Node.js `24.18.0`, npm `11.16.0`, Terraform `1.15.8`, Docker, and
GNU Make.

```bash
make setup
make validate
make run
```

The API listens on `http://localhost:8080`:

```text
GET /health
GET /ready
GET /api/v1/greeting?name=Ada
```

Run `make help` for individual validation targets. `make tf-plan` is
credential-free in this foundation slice and cannot create infrastructure.

## Repository map

```text
src/                 HTTP API
test/                Unit and integration tests
infra/terraform/     Terraform foundation contract
docs/                Architecture, ADRs, runbooks, and readiness gaps
.github/workflows/   CI and security checks
.codex/              Repository-backed AI working context
```

## Delivery model

This repository uses lightweight Gitflow:

- `main`: stable releases only
- `develop`: integration
- `feature/*`, `fix/*`, `chore/*`, `docs/*`, `test/*`: review branches
- `release/*`: release stabilization
- `hotfix/*`: production fixes

All changes reach `develop` or `main` through pull requests using Conventional
Commit titles.

## Architecture

Start with [the architecture overview](docs/architecture.md), then read the
[runbooks](docs/runbooks.md) and
[production-readiness gap analysis](docs/production-readiness.md).

## License

No license has been selected yet. The source is public for portfolio review,
but reuse rights are not granted until a license is added.
