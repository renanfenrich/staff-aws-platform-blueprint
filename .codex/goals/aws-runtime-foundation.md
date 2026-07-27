# AWS runtime foundation

## Objective

Represent the disposable sandbox network and ECS Fargate runtime as a
cost-gated Terraform graph that can be reviewed without AWS credentials.

## In scope

- VPC, two public subnets, internet gateway, routing, and associations
- separate ALB and ECS task security groups
- internet-facing HTTP ALB, IP target group, and listener
- immutable scan-on-push ECR repository and lifecycle policy
- ECS cluster, hardened Fargate task definition, and one-task service
- separate task execution and empty application roles
- bounded CloudWatch application log group and `awslogs`
- Terraform mock-provider tests and enabled Trivy scan fixture
- architecture, readiness, runbook, and ADR updates

## Explicit exclusions

- AWS resource creation or credentials
- OIDC, remote state, apply, deploy, promotion, and destroy workflows
- image build, push, signing, attestation, or promotion
- Route 53, ACM, TLS, WAF, NAT, VPC endpoints, autoscaling, dashboards,
  alarms, budgets, EFS, Secrets Manager, and production implementation

## Safety boundaries

- `deployment_enabled=false` is the default.
- Disabled planning must make no AWS API request and contain zero resource
  changes.
- Enabled graph tests must use Terraform's mock AWS provider.
- Tasks have no public ingress, SSH, administrative port, or ECS Exec.
- The application role has no permissions.
- Images must use a `sha256` digest and never `latest`.
- No cloud mutation command is permitted in this slice.

## Acceptance criteria

- Disabled plan asserts zero AWS resource changes.
- Mock tests cover enabled resources, two Availability Zones, security-group
  paths, IAM actions, ECR lifecycle, log retention, service rollback, tags,
  digest validation, Fargate sizing, and the production network rejection.
- Terraform, application, documentation, workflow, and security validations
  pass.
- Documentation states that no AWS deployment or operational validation has
  occurred.
- The change is delivered on `feature/aws-runtime-foundation` through a ready
  pull request to `develop`.

## Next expected slice

Bootstrap encrypted remote state and implement repository- and
environment-bound GitHub AWS OIDC. Follow with build-once image publication and
protected plan, apply, and destroy workflows.
