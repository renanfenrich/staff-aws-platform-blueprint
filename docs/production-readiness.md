# Production-readiness gap analysis

## Maturity statement

This is a safe foundation, not a deployable production platform. It creates no
AWS resources and makes no production-readiness claim.

## Implemented in this slice

| Area | Evidence |
| --- | --- |
| API | Health, readiness, example behavior, config validation, JSON logs, graceful shutdown |
| Container | Exact base digest, multi-stage build, non-root runtime, no runtime npm dependencies |
| Local quality | Make targets for setup, lint, typecheck, tests, security, Terraform, and docs |
| Supply chain | Exact npm and action pins, Dependabot, CodeQL, Gitleaks, Trivy, dependency review, SBOM |
| Terraform contract | Exact versions, safe toggles, validated inputs, mandatory tags, credential-free plan |
| Operations | Architecture, threat and cost models, runbooks, DR assumptions, and ADRs |

## Required before sandbox deployment

- Implement VPC, subnets, routing, security groups, ECR, ALB, ECS, and log groups.
- Implement separate task execution and application roles with policy tests.
- Bootstrap encrypted, versioned remote state with locking through an approved
  one-time process.
- Implement repository- and environment-bound GitHub OIDC.
- Add CloudWatch dashboards and alarms with a tested notification destination.
- Add AWS Budget actual and forecast alerts.
- Add manual plan, approved apply, and confirmation-protected destroy workflows.
- Build once, scan, attest, push by digest, and promote the same artifact.
- Add Terraform policy checks for public exposure, encryption, logging, and tags.
- Run a sandbox deployment, smoke test, rollback, destroy, and cost review.

## Required before production

- Use private application subnets and a reviewed redundant egress design.
- Require TLS with managed certificate, DNS ownership, WAF decision, access
  logging, and documented rate controls.
- Set production capacity, autoscaling, circuit breaker, deployment health, log
  retention, SLOs, paging, and ownership.
- Protect `main` and the GitHub `production` environment with required reviewers.
- Define and test RTO, RPO, alternate-region recovery, state recovery, and image
  retention.
- Complete penetration, threat-model, IAM, Terraform plan, and cost reviews.
- Decide licensing and security disclosure policy for the public repository.

## Optional profiles intentionally deferred

- WAF is opt-in because it has standing and request costs.
- EFS is opt-in because the example workload is stateless and persistence
  changes recovery and security obligations.
- NAT gateways and VPC endpoints require a workload-specific traffic and
  availability decision.

The recommended next slice is the cost-gated network and ECS runtime with no
deployment workflow.
