# ADR 0008: Keep bootstrap state human-controlled

- Status: Accepted
- Date: 2026-07-27

## Context

The state bucket and GitHub identity cannot initially use infrastructure that
does not yet exist. Giving GitHub access to bootstrap state would also let a
repository workflow alter the identity and storage boundary that authorizes it.
An AWS account may already contain the singleton GitHub Actions OIDC provider.

## Decision

Keep `infra/bootstrap` independent and local-state-first. A short-lived human
operator session will eventually review and create the foundation. Only after
the bucket controls are verified may a separate reviewed change add the partial
S3 backend and migrate bootstrap state to:

```text
staff-aws-platform-blueprint/bootstrap/terraform.tfstate
```

The GitHub sandbox role receives no access to that object or lock. Runtime state
uses a separate sandbox key. If the standard account-level GitHub provider
already exists, accept its exact ARN, create no provider resource, and do not
import, modify, or manage its lifecycle.

## Consequences

Bootstrap retains a deliberate human recovery and privilege boundary. Initial
local state is sensitive and must be backed up and protected until remote
migration is verified. The two-phase process adds operator steps but prevents a
workflow from rewriting its own trust root or accidentally deleting a shared
OIDC provider.
