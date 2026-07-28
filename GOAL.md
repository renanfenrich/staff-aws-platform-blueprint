# Goal

Build a production-oriented AWS platform blueprint for a small containerized
API, delivered through Terraform and GitHub Actions.

## Current slice: immutable image publication foundation

Resolve the first-deployment image and registry ordering problem before an AWS
sandbox plan can reference a real application digest:

- move the protected ECR repository into the bootstrap lifecycle;
- add a separate exact-subject OIDC image-publisher role;
- make runtime Terraform consume an external repository and matching digest;
- define manual-only preflight, build, and publish jobs;
- build once for Linux X86_64, scan before AWS authentication, and generate an
  SPDX JSON SBOM from that same image;
- transfer the checksummed image archive without rebuilding;
- publish a unique traceability tag and resolve one immutable ECR digest;
- publish and verify digest-bound provenance and SBOM attestations;
- preserve credential-free local, pull-request, and mock-provider validation.

## Scope boundary

This slice does not apply Terraform, create ECR, migrate state, initialize a
remote backend, authenticate to AWS, publish an image, create or protect a
GitHub environment, enable the runtime graph, update ECS, register a task
definition, or add plan, apply, deployment, promotion, destroy, recovery, or
production automation.

## Completion evidence

- `make validate`
- `make security`
- `make tf-plan`
- `make tf-test`
- `make bootstrap-plan-disabled`
- `make bootstrap-test`
- `make image-build`
- `make image-scan`
- `make image-sbom`
- `make image-publication-check`
- `git diff --check`
- reviewed diff with no runtime-owned ECR, broad publisher action, image
  deletion, mutable tag, second build, pre-scan AWS authentication, static
  credential, unpinned action, AWS mutation, or generated state and plan file
