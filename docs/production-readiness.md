# Production-readiness gap analysis

## Maturity statement

The repository contains a deployable Terraform runtime graph, a separate
remote-state, OIDC, ECR, and image-publisher bootstrap, and a manual build-once
publication workflow. Neither Terraform graph has been applied and the workflow
has not run. No repository, role, image, scan result, attestation, remote
initialization, AWS identity smoke, rollback, destroy, or cost review has
occurred. The GitHub `sandbox` environment was absent when inspected. This is
neither an operational sandbox nor a production-ready platform.

## Implemented and locally validated

| Area | Evidence |
| --- | --- |
| API | Health, readiness, example behavior, config validation, JSON logs, graceful shutdown |
| Container | Exact base digest, multi-stage build, non-root runtime, no runtime npm dependencies |
| Network graph | Two-AZ public VPC, internet routing, separate ALB and task security groups |
| Runtime graph | External digest-form ECR input, ALB, ECS cluster, hardened Fargate task and service, CloudWatch logs |
| IAM graph | ECS-only trusts, scoped execution policy, empty application role |
| Cost safety | Default-disabled modules, zero-resource plan assertion, no NAT, bounded logs and images |
| Terraform tests | Mock-provider enabled graph, security boundaries, IAM, lifecycle, rollback, tags, and invalid-input tests |
| State graph | SSE-S3, versioning, public-access block, ownership, TLS deny, native locking, 90-day recovery |
| OIDC graph | Exact immutable repository/environment subject, short sessions, external-provider mode |
| State IAM | Exact sandbox state and lock objects; no state deletion, bootstrap access, or workload actions |
| Smoke workflow | Manual-only identity and bucket-control checks with job-level OIDC permission |
| Registry graph | Bootstrap-owned immutable, scan-on-push, SSE-S3 ECR with prevent-destroy and subject-focused retention |
| Publisher IAM | Exact environment trust; one repository; no delete, repository mutation, state, or workload action |
| Publication workflow | Manual `develop` dispatch, one X86_64 build, pre-auth Trivy and SPDX SBOM, checksummed transfer, digest resolution, two attestations, bounded verification |
| Supply chain | Exact npm, provider, tool, image, and action pins; shared scan and SBOM scripts |

## Required before the first sandbox apply

- Execute the documented human bootstrap only after account, plan, and cost
  approval, then verify every bucket, ECR, publisher, and trust-policy control.
- Preview the ECR lifecycle policy and confirm subject/referrer handling before
  accepting its first real expiration.
- Create and protect the GitHub environment exactly as `sandbox`, restrict it to
  `develop`, and add a required reviewer where supported.
- Run the manual OIDC smoke, migrate bootstrap state to its protected key, and
  initialize runtime state against the sandbox key.
- Configure the four non-secret publication environment variables, run the OIDC
  smoke, set `AWS_IMAGE_PUBLISH_READY=true`, dispatch publication from
  `develop`, and review local and ECR scans, SBOM, provenance, referrers, and the
  immutable digest.
- Add a manual plan workflow that uploads one reviewed plan artifact.
- Add a protected sandbox apply workflow that consumes exactly that plan.
- Add a confirmation-protected destroy workflow for the exact sandbox.
- Add CloudWatch dashboards and alarms with a tested notification destination.
- Add AWS Budget actual and forecast alerts and verify the recipient.
- Review the target AWS account, region, Availability Zones, service quotas,
  mandatory tag values, costs, and time-bounded Trivy exceptions.
- Run a sandbox deployment, endpoint smoke test, log verification, rollback,
  destroy, residual-resource check, and cost review.

No maintainer should manually enable the current root module before those
controls exist. The repository intentionally includes no apply, deploy,
promotion, or destroy automation.

## Required before production

- Replace public task placement with private application subnets and a reviewed
  redundant NAT or VPC endpoint design.
- Require ACM TLS, owned DNS, HTTP-to-HTTPS redirect, ALB access logging, and a
  reviewed WAF and rate-control decision.
- Set production capacity, autoscaling, circuit-breaker thresholds, log
  retention, SLOs, paging, and ownership from measured demand.
- Protect `main` and the GitHub `production` environment with required reviewers
  and separate production IAM boundaries.
- Define and test RTO, RPO, alternate-region recovery, state recovery, image
  retention, and security incident procedures.
- Complete penetration, threat-model, IAM, Terraform plan, cost, privacy, and
  operational-readiness reviews.
- Decide licensing and a security disclosure policy for the public repository.

## Known sandbox limitations

- Traffic from the client to the ALB is plaintext HTTP.
- Tasks use public IPv4 addresses for egress, although their security group has
  no public ingress.
- Task HTTPS egress allows any IPv4 destination on TCP port 443 because ECR,
  signed layer storage, CloudWatch Logs, and other public AWS endpoint ranges
  are not stable security-group targets.
- There is one task by default, so updates and failures can temporarily reduce
  capacity.
- Container Insights, metrics, alarms, access logs, WAF, autoscaling, budgets,
  Secrets Manager integration, and persistence are absent.
- ECR scan-on-push is represented, but no image has been pushed or scan result
  observed.
- The publisher role, repository immutability, OCI referrers, provenance, SBOM
  attestation, cryptographic verification, and post-push failure path have only
  static or mock evidence.
- AES-256 ECR encryption uses the AWS-managed service key; a customer-managed
  key decision is deferred to production requirements.
- State uses cost-conscious SSE-S3; a dedicated KMS key remains a production
  decision.
- Remote-state recovery, locking, OIDC assumption, and GitHub environment
  protection have only configuration or API-inspection evidence.

## Optional profiles intentionally deferred

- WAF has standing and request costs and requires a rule and ownership decision.
- EFS changes backup, recovery, access, and encryption obligations for an API
  that is currently stateless.
- NAT gateways and VPC endpoints need a workload-specific traffic and
  availability comparison.
- ARM64 may reduce compute cost, but it requires a proven multi-architecture
  build, scan, and performance path first.

The recommended next slice is the approved external bootstrap and environment
preparation, lifecycle preview, OIDC smoke, and first image publication. Only
after those controls are operationally verified should a separate protected
Terraform plan workflow consume the recorded digest. Apply and destroy remain
later separate slices.
