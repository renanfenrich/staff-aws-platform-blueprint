# ADR 0012: Use Trivy as the image-publication gate

- Status: Accepted
- Date: 2026-07-28

## Context

The first live image publication passed the pinned pre-authentication Trivy
scan and pushed one immutable digest, but ECR Basic scanning remained
`IN_PROGRESS` beyond the workflow's bounded polling window. That asynchronous
registry status prevented provenance and SBOM attestation of an image that had
already passed the broader OS and library package gate.

## Decision

The pinned Trivy image scan is the authoritative synchronous publication gate.
It scans the exact local image for fixed HIGH and CRITICAL operating-system and
library vulnerabilities before AWS authentication, writes JSON evidence, and
fails closed when findings exist or the scanner fails.

ECR Basic scan on push remains enabled as asynchronous defense-in-depth. The
publication workflow verifies that repository control but neither polls nor
reads ECR findings, and the publisher role has no
`ecr:DescribeImageScanFindings` permission. A clean Trivy result proceeds from
digest resolution directly to provenance, SBOM attestation, and verification.

## Consequences

Publication no longer depends on ECR scan latency. ECR findings are advisory
after publication and must be reviewed before a future deployment or
promotion. Continuous registry reassessment with Amazon Inspector and
EventBridge requires a separate cost and operations decision.

The immutable digest from the failed first run remains retained and unattested.
Recovering it requires the separate reviewed existing-digest workflow already
defined by ADR 0010; this decision does not add one.
