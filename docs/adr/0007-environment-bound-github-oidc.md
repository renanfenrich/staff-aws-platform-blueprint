# ADR 0007: Bind GitHub OIDC to one protected environment

- Status: Accepted
- Date: 2026-07-27

## Context

Long-lived AWS access keys in GitHub would create rotation and exposure risk.
Name-only OIDC subjects can also become ambiguous after repository renames or
namespace reuse.

On 2026-07-27, the GitHub API reported repository ID `1314297578`, owner ID
`1413054`, `use_default=true`, `use_immutable_subject=false`, and the active
`sub_claim_prefix`:

```text
repo:renanfenrich@1413054/staff-aws-platform-blueprint@1314297578
```

The repository was created after GitHub's immutable-subject rollout. The API's
returned active prefix therefore establishes the environment subject used by
this decision:

```text
repo:renanfenrich@1413054/staff-aws-platform-blueprint@1314297578:environment:sandbox
```

The `sandbox` environment endpoint returned 404 during the same inspection.
No protection is claimed or created by this change.

## Decision

Use GitHub OIDC with issuer `https://token.actions.githubusercontent.com`,
audience `sts.amazonaws.com`, and the exact environment subject above. The IAM
trust policy uses only `StringEquals`; no wildcard or `StringLike` is allowed.
Only the manual smoke workflow identity job receives job-level
`id-token: write`, uses a 900-second session, and never logs the JWT or
credentials.

Require maintainers to create the environment exactly as `sandbox`, limit
deployment branches to `develop`, and configure a required reviewer where the
repository plan supports it. Store role ARN, region, and bucket name as
non-secret variables. Store no AWS access keys. A repository readiness variable
must be set only after these controls and AWS bootstrap are verified.

## Consequences

Repository and environment identity is stable across renames. A compromised
trusted workflow on `develop` can still request a short-lived state session
after environment approval; branch protection, environment review, narrow role
permissions, and workflow review remain required. The state role is not a
runtime plan, apply, deployment, or role-chaining identity.
