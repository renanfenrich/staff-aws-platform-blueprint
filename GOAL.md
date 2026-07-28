# Goal

Build a production-oriented AWS platform blueprint for a small containerized
API, delivered through Terraform and GitHub Actions.

## Current slice: remote-state and OIDC foundation

Represent the security prerequisites required before an AWS sandbox plan or
deployment workflow can exist:

- an isolated, default-disabled Terraform bootstrap root;
- an encrypted, versioned, private S3 state bucket with native lockfiles;
- repository-ID and `sandbox` environment-bound GitHub OIDC;
- a least-privilege sandbox state role;
- partial backend configuration for the runtime root;
- deterministic mock-provider and static security tests;
- a manual, non-mutating identity smoke workflow;
- bootstrap, recovery, and state-migration documentation.

## Scope boundary

This slice does not create AWS resources, migrate state, create or protect a
GitHub environment, publish an image, enable the runtime graph, or add plan,
apply, deployment, promotion, destroy, workload-management, or production
automation.

## Completion evidence

- `make validate`
- `make tf-plan`
- `make tf-test`
- `make bootstrap-validate`
- `make bootstrap-plan-disabled`
- `make bootstrap-test`
- `make security`
- `git diff --check`
- reviewed diff with no credentials, wildcard trust, broad S3 access,
  bootstrap-state access from GitHub, public state access, or unpinned
  automation
