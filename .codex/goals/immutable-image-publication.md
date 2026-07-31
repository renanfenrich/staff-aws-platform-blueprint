# Immutable image publication foundation

## Objective

Separate durable software artifacts from the disposable runtime lifecycle and
represent a build-once, scan-before-authentication publication path whose output
is one immutable ECR digest.

## In scope

- bootstrap-owned immutable ECR repository and artifact-aware lifecycle policy
- dedicated environment-bound GitHub OIDC image-publisher role
- runtime inputs for an external repository ARN, URL, and matching image digest
- manual-only `develop` publication with preflight, build, and publish jobs
- one X86_64 image build, Trivy gate, SPDX JSON SBOM, and archive checksum
- unique `git-` traceability tag and registry digest resolution
- digest-bound provenance and SBOM attestations published as OCI referrers
- authoritative pre-authentication Trivy gating, asynchronous ECR scan on push,
  and cryptographic attestation verification
- mock-provider tests, static workflow checks, local targets, ADRs, and runbooks

## Safety boundaries

- Both Terraform roots remain default-disabled and credential-free locally.
- No Terraform apply, state migration, AWS authentication, image push, ECS
  update, task registration, deployment, destroy, or production action occurs.
- Publication is blocked until two readiness variables and the protected
  `sandbox` environment are externally verified.
- Only the publish job may request OIDC and attestation permissions.
- The publisher can push and verify one repository but cannot delete images,
  manage repository configuration, access state, or manage workloads.
- Runtime Terraform consumes only the configured repository URL plus a
  `sha256` digest; it never consumes the traceability tag.

## Acceptance evidence

- bootstrap mock tests prove 14 resources with a created OIDC provider and 13
  with an existing provider
- runtime mock tests prove 26 managed resources and external ECR pull scoping
- publication static checks prove manual-only, build-once, permission, ordering,
  pinning, retention, and no-deployment boundaries
- local image build, Trivy scan, SPDX SBOM, full validation, and security scans
  pass without AWS access
- a ready pull request targets `develop`

## Next expected slice

Prepare and review the bootstrap-state migration from protected local state to
the protected S3 bootstrap key. Do not reapply the publisher-policy narrowing or
rerun publication merely to prove attestations; the successful hosted run
already verified both attestations and the OCI referrers. Runtime initialization,
protected plan/apply/destroy workflows, and deployment remain separate later
slices.
