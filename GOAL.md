# Goal

Build a production-oriented AWS platform blueprint for a small containerized
API, delivered through Terraform and GitHub Actions.

## Current slice: digest attestation registry credentials

Allow the pinned digest-attestation action to use the existing scoped ECR login
without persisting or broadening registry credentials:

- verify the temporary Docker configuration contains only the configured ECR
  registry entry before exposing it to `actions/attest`;
- copy it at mode `0600` only to the action's default Docker configuration path;
- remove both credential files in an `always()` cleanup;
- preserve credential-free local, pull-request, and mock-provider validation.

## Scope boundary

This slice does not apply IAM changes, authenticate to AWS, publish or recover
an image, migrate state, initialize a remote backend, enable the runtime graph,
update ECS, register a task definition, or add plan, apply, deployment,
promotion, destroy, recovery, Inspector, or EventBridge automation.

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
- reviewed diff with no runtime-owned ECR, image deletion, mutable tag, second
  build, pre-scan AWS authentication, static credential, unpinned action, AWS
  mutation, or generated state and plan file
