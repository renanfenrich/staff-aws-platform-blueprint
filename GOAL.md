# Goal

Build a production-oriented AWS platform blueprint for a small containerized
API, delivered through Terraform and GitHub Actions.

## Current slice: initial foundation

Deliver:

- repository and AI working agreements;
- a minimal, tested, containerized HTTP API;
- deterministic local validation commands;
- pinned CI, security scanning, and dependency updates;
- an offline-safe Terraform input and tagging contract;
- architecture, threat, cost, runbook, ADR, and readiness documentation.

## Scope boundary

This slice must not create or mutate AWS resources. VPC, ECS Fargate, ALB, IAM,
OIDC, observability, budgets, WAF, persistence, deployment, and destroy
implementations remain explicitly planned work.

## Completion evidence

- `make validate`
- `make security`
- `make container`
- `make tf-plan`
- reviewed diff with no credentials or unpinned GitHub Actions
