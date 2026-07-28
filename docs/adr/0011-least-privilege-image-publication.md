# ADR 0011: Use a least-privilege image-publisher role

- Status: Accepted
- Date: 2026-07-27

## Context

The state role protects Terraform objects and must not become a workload or
artifact identity. Reusing an ECS role or future Terraform role would combine
unrelated trust, permissions, and recovery responsibilities.

## Decision

Create `staff-aws-platform-blueprint-sandbox-image-publisher` separately from
the state and runtime roles. It trusts only the exact GitHub provider, audience
`sts.amazonaws.com`, and immutable subject:

```text
repo:renanfenrich@1413054/staff-aws-platform-blueprint@1314297578:environment:sandbox
```

The trust uses `StringEquals`, has no wildcard, permits only
`sts:AssumeRoleWithWebIdentity`, and caps sessions at one hour. The protected
workflow requests 900 seconds and skips session tagging.

The policy allows `ecr:GetAuthorizationToken` on `"*"` because AWS cannot
resource-scope that operation. On the exact repository ARN it allows layer
upload, image manifest publication, image reads, digest and scan inspection,
and `DescribeRepositories` to verify the configured repository, immutable-tag,
scan-on-push, and encryption controls. `ListImageReferrers` is authorized by
the included `BatchGetImage` action. No delete, repository mutation, state,
ECS, EC2, IAM mutation, CloudWatch mutation, secret, KMS administration, or
role-chaining action is granted.

## Environment boundary

The workflow remains blocked until the bootstrap exists, trust is verified,
the `sandbox` environment is protected for `develop`, OIDC smoke succeeds, and
the two readiness variables are set. Only the publish job enters the dynamic
environment and receives OIDC and attestation permissions.

## Consequences

A compromised trusted publication workflow could still push an immutable
malicious image after environment approval. Review protection, exact
environment variables, a short session, repository-scoped permissions,
scan-before-authentication, and digest-bound evidence reduce but do not
eliminate that residual risk.
