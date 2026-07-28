# Goal

Build a production-oriented AWS platform blueprint for a small containerized
API, delivered through Terraform and GitHub Actions.

## Current slice: authoritative Trivy publication gate

Prevent asynchronous ECR Basic scanning from blocking digest attestation after
the exact image has already passed the pre-authentication Trivy policy:

- keep the pinned Trivy HIGH and CRITICAL OS and library scan as the synchronous,
  fail-closed publication gate;
- keep ECR scan on push enabled as asynchronous defense-in-depth without polling
  its findings during publication;
- proceed directly from immutable digest resolution to provenance, SBOM
  attestation, and verification;
- remove the unused ECR scan-findings permission from the publisher role;
- preserve credential-free local, pull-request, and mock-provider validation.

## Scope boundary

This slice does not apply the publisher IAM narrowing, authenticate to AWS,
publish or recover an image, migrate state, initialize a remote backend, enable
the runtime graph, update ECS, register a task definition, or add plan, apply,
deployment, promotion, destroy, recovery, Inspector, or EventBridge automation.

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
- reviewed diff with no ECR findings poll or permission, runtime-owned ECR,
  image deletion, mutable tag, second build, pre-scan AWS authentication,
  static credential, unpinned action, AWS mutation, or generated state and plan
  file
