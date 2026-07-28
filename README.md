# staff-aws-platform-blueprint

A production-oriented reference blueprint for running a small containerized
HTTP API on AWS ECS Fargate with Terraform and GitHub Actions.

> **Foundation status:** Terraform represents a deployable, disposable sandbox
> runtime plus an isolated encrypted remote-state and GitHub OIDC bootstrap.
> Both roots remain disabled by default, all enabled validation uses mocks, no
> AWS resource exists, and the repository is not production-ready.

## What this demonstrates

- A dependency-light Node.js 24 API with health, readiness, structured logging,
  configuration validation, and graceful shutdown.
- A non-root, digest-pinned container image suitable for a read-only filesystem.
- A two-AZ public sandbox VPC, internet-facing ALB, ECR repository, ECS Fargate
  service, runtime IAM roles, and bounded CloudWatch logs.
- Separate ALB and task security groups with no public task ingress.
- An explicit `deployment_enabled = false` cost gate and a credential-free plan
  that proves zero AWS resource changes.
- Mock-provider Terraform tests for the enabled resource graph.
- A separate `bootstrap_enabled = false` root representing an encrypted,
  versioned, TLS-only S3 state bucket with native S3 lockfiles.
- An exact repository-ID and `sandbox` environment-bound GitHub OIDC state role
  with object-level state and lock permissions.
- A manual, non-mutating AWS identity and state-bucket control smoke workflow.
- SHA-pinned CI and security workflows, Dependabot, CodeQL, Gitleaks, Trivy,
  dependency review, container scanning, and SBOM generation.

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

Terraform stays safe by default:

```bash
make tf-plan
make tf-test
make bootstrap-plan-disabled
make bootstrap-test
```

`make tf-plan` uses non-secret, process-local placeholder values required by the
AWS provider SDK, disables provider validation and metadata lookup, performs no
AWS API request, and fails if the disabled plan contains any resource change.
`make tf-test` uses Terraform's mock AWS provider to validate the enabled graph.
Neither command needs AWS credentials.

The bootstrap targets also need no AWS credentials. The runtime root has a
partial S3 backend, but offline commands use `terraform init -backend=false`.
Future remote initialization requires an explicit untracked configuration:

```bash
make tf-init-remote BACKEND_CONFIG=infra/terraform/backend.hcl
```

No supported apply path exists. Do not set `bootstrap_enabled=true` or
`deployment_enabled=true` outside the approved future procedures in
[the runbooks](docs/runbooks.md).

## Repository map

```text
src/                 HTTP API
test/                Unit and integration tests
infra/bootstrap/     Cost-gated state and GitHub OIDC foundation
infra/terraform/     Cost-gated AWS runtime modules, backend, and tests
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
