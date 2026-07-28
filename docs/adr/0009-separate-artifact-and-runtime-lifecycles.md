# ADR 0009: Separate artifact and runtime lifecycles

- Status: Accepted
- Date: 2026-07-27

## Context

The runtime root owned the ECR repository only when `deployment_enabled=true`,
but the same enabled graph required an existing digest-form image. A first
runtime deployment therefore could neither create the empty repository first
nor supply a real image already published to it. Runtime destroy would also
couple disposable compute replacement to retained software evidence.

## Decision

Move the single ECR implementation to the human-controlled bootstrap root. The
bootstrap ordering is remote state, GitHub OIDC, state role, protected ECR
repository, and image-publisher role; manual image publication follows, and a
future runtime plan consumes the existing repository ARN, URL, and immutable
digest.

The repository uses immutable tags, scan on push, SSE-S3, `force_delete=false`,
mandatory tags, and `prevent_destroy=true`. Its lifecycle policy targets only
published application subjects tagged `git-` and retains the newest 30. It has
no generic untagged rule because OCI referrer behavior must first be previewed
in the target account.

The created-provider bootstrap graph grows from 10 to 14 resources; the
existing-provider graph grows from 9 to 13. The runtime graph drops from 28 to
26 resources. Normal runtime replacement or destruction cannot remove the
repository or its published evidence.

## State consequence

No AWS graph has been applied and no Terraform state exists, so no `moved`,
import, or migration block is appropriate. If an undisclosed out-of-band apply
already created the runtime ECR resource, operators must stop and design a
reviewed state migration before applying either root. They must not let
Terraform create a second repository or forget the existing artifact state.

## Consequences

Bootstrap is intentionally longer-lived than the disposable runtime. Images,
provenance, SBOM attestations, and future signatures consume ECR storage and
quota. Reference artifacts should remain attached to their subject; ECR
lifecycle handling removes attached artifacts after their subject expires.
Lifecycle preview is mandatory before the first real bootstrap apply.
