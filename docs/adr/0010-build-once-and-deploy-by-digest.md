# ADR 0010: Build once and deploy by digest

- Status: Accepted
- Date: 2026-07-27

## Context

Scanning one image and rebuilding another for publication would make the scan,
SBOM, and runtime identity unrelated. Mutable tags would allow later
substitution even if the original build was reviewed.

## Decision

The manual publication workflow performs exactly one Linux X86_64 container
build from the selected `develop` commit. It scans that local image with Trivy
before AWS authentication, produces an SPDX JSON SBOM from the same image,
saves the image archive, records SHA-256 checksums, and transfers the archive
between jobs. The publish job verifies the checksum, loads the archive, and
pushes it without rebuilding.

Publication uses the unique traceability tag
`git-${GITHUB_SHA}-${GITHUB_RUN_ID}`. After push, ECR resolves that tag to one
registry digest. GitHub provenance and SPDX SBOM attestations use the repository
URL as subject name and the same `sha256` digest as subject digest, then publish
as OCI reference artifacts. Cryptographic verification identifies this source
repository and distinguishes provenance from the SPDX predicate.

Terraform never consumes the traceability tag. A future reviewed plan receives
only `ECR_REPOSITORY_URL@sha256:DIGEST`.

## Failure semantics

Failures before push leave no ECR image. A failure after push does not trigger
deletion, retagging, or rebuilding: the immutable digest and available scan and
SBOM evidence remain, the run fails, and an operator investigates the missing
attestation or verification. Recovery against an existing digest requires a
future separate, explicitly reviewed workflow.

## Consequences

The image archive is retained for one day only as a run-scoped transfer
artifact. Security and publication evidence are retained for 14 days. The
workflow does not deploy, update ECS, register a task definition, or commit the
digest to Terraform.
