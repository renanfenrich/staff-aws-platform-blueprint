# Remote-state and OIDC foundation

## Objective

Represent encrypted Terraform remote state, native S3 locking, and exact
repository/environment-bound GitHub AWS OIDC without contacting or changing
AWS.

## In scope

- isolated, local-state-first bootstrap root with a default-off cost gate
- private, ownership-enforced, versioned, SSE-S3 state bucket
- TLS-only bucket policy and 90-day noncurrent-version recovery window
- created-provider and external-provider GitHub OIDC modes
- exact immutable repository-ID subject for the `sandbox` environment
- least-privilege sandbox state and lockfile access role
- partial runtime backend and explicit initialization targets
- manual, non-mutating OIDC smoke workflow
- mock-provider tests, static checks, CI, security scans, ADRs, and runbooks

## Explicit exclusions

- AWS API requests, bootstrap apply, state migration, or cloud resources
- GitHub environment creation or protection changes
- runtime enablement, image publication, Terraform plan/apply/destroy workflows
- workload-management permissions, role chaining, or production roles
- DynamoDB state locking, KMS key, Object Lock, replication, and access logging

## Safety boundaries

- `bootstrap_enabled=false` and `deployment_enabled=false` remain defaults.
- Both disabled plans contain zero resource changes and work offline.
- Enabled graphs are validated only with mock AWS providers.
- GitHub cannot access the bootstrap state key.
- State deletion is denied; only the lock object can be deleted.
- The exact `aud` and immutable environment `sub` use `StringEquals`.
- No long-lived AWS credentials or implicit migration/apply target exists.

## Acceptance evidence

- all required local validation and security scans pass
- API evidence records the immutable repository prefix and missing environment
- no AWS API request, resource creation, state migration, or deployment occurs
- ready pull request targets `develop`

## Next expected slice

Build once, scan, attest, and publish one immutable image digest before adding
separate protected plan, apply, and destroy workflows.
