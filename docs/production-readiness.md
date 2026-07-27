# Production-readiness gap analysis

## Maturity statement

The repository contains a deployable Terraform resource graph for a disposable
sandbox. It has not been applied, smoke-tested, rolled back, destroyed, or cost
reviewed in AWS. It is neither an operational sandbox nor a production-ready
platform.

## Implemented and locally validated

| Area | Evidence |
| --- | --- |
| API | Health, readiness, example behavior, config validation, JSON logs, graceful shutdown |
| Container | Exact base digest, multi-stage build, non-root runtime, no runtime npm dependencies |
| Network graph | Two-AZ public VPC, internet routing, separate ALB and task security groups |
| Runtime graph | ECR, ALB, ECS cluster, hardened Fargate task and service, CloudWatch logs |
| IAM graph | ECS-only trusts, scoped execution policy, empty application role |
| Cost safety | Default-disabled modules, zero-resource plan assertion, no NAT, bounded logs and images |
| Terraform tests | Mock-provider enabled graph, security boundaries, IAM, lifecycle, rollback, tags, and invalid-input tests |
| Supply chain | Exact npm, provider, tool, image, and action pins; scans and SBOM |

## Required before the first sandbox apply

- Bootstrap encrypted, versioned remote state with locking through an approved
  one-time process.
- Implement repository- and environment-bound GitHub OIDC with short sessions.
- Build once, scan, attest, and push the API image to ECR, then record its
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
- AES-256 ECR encryption uses the AWS-managed service key; a customer-managed
  key decision is deferred to production requirements.

## Optional profiles intentionally deferred

- WAF has standing and request costs and requires a rule and ownership decision.
- EFS changes backup, recovery, access, and encryption obligations for an API
  that is currently stateless.
- NAT gateways and VPC endpoints need a workload-specific traffic and
  availability comparison.
- ARM64 may reduce compute cost, but it requires a proven multi-architecture
  build, scan, and performance path first.

The recommended next slice is encrypted remote state and GitHub AWS OIDC,
followed by build-once image publishing and protected plan/apply/destroy
workflows.
