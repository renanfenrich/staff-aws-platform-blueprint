# Architecture overview

## Status and scope

Terraform represents the disposable sandbox runtime plus a separate state and
identity bootstrap. `deployment_enabled` and `bootstrap_enabled` both default
to `false`; local plans contain zero AWS resource changes and do not authenticate
to AWS. Enabled graphs have been validated only with mock AWS providers. No
resource, remote state, OIDC session, or deployment has been operationally
tested in AWS.

## State and identity bootstrap

```mermaid
flowchart LR
  Operator[Short-lived human operator] --> Bootstrap[Local-state bootstrap root]
  Bootstrap --> Bucket[Encrypted versioned S3 bucket]
  Bootstrap --> Provider[GitHub OIDC provider or external ARN]
  Provider --> Role[Sandbox state role]
  Workflow[Manual protected-environment smoke] -->|exact OIDC subject| Role
  Role -->|Get and Put| State[Sandbox state object]
  Role -->|Get, Put, and Delete| Lock[Sandbox lock object]
  Operator -->|human-only boundary| BootstrapState[Bootstrap state object]
```

The bootstrap root is isolated under `infra/bootstrap` and initially keeps
local state. When enabled in a future approved operation, it represents ten AWS
resources: one S3 bucket plus ownership controls, public-access block,
versioning, SSE-S3 encryption, lifecycle policy, and TLS-only bucket policy;
one GitHub OIDC provider, IAM role, and inline policy. Referencing an existing
account-level provider reduces the inventory to nine and never manages the
shared provider.

The bucket has no ACL, website, Object Lock, replication, cross-account grant,
or logging bucket. It uses Bucket Owner Enforced ownership, all four public
access blocks, AES-256 default encryption, versioning, accidental-destroy
protection, a 90-day noncurrent-version recovery window, and seven-day cleanup
of incomplete multipart uploads. Current state never expires.

The partial runtime S3 backend uses encryption and native `.tflock` locking.
Credentials remain process-local from a future short-lived OIDC session and
must never enter backend configuration. DynamoDB locking is not used.

## State keys and permissions

| Object | Owner | Allowed object actions |
| --- | --- | --- |
| `staff-aws-platform-blueprint/bootstrap/terraform.tfstate` | Human bootstrap operator | Not granted to GitHub |
| `staff-aws-platform-blueprint/bootstrap/terraform.tfstate.tflock` | Human bootstrap operator | Not granted to GitHub |
| `staff-aws-platform-blueprint/sandbox/terraform.tfstate` | GitHub sandbox state role | `GetObject`, `PutObject` |
| `staff-aws-platform-blueprint/sandbox/terraform.tfstate.tflock` | GitHub sandbox state role | `GetObject`, `PutObject`, `DeleteObject` |

The state role may list only the exact sandbox state and lock prefixes and read
bucket location, versioning, encryption, and public-access-block settings. It
has no workload-management action, state deletion, role chaining, or bootstrap
state access.

## GitHub identity boundary

GitHub API evidence on 2026-07-27 returned owner ID `1413054`, repository ID
`1314297578`, and immutable prefix
`repo:renanfenrich@1413054/staff-aws-platform-blueprint@1314297578`. The role
therefore requires:

```text
aud = sts.amazonaws.com
sub = repo:renanfenrich@1413054/staff-aws-platform-blueprint@1314297578:environment:sandbox
```

Both conditions use `StringEquals`. The provider URL is exactly
`https://token.actions.githubusercontent.com`; no maintained certificate
thumbprint is configured. The role session maximum is one hour, while the smoke
workflow requests 15 minutes.

Only the manual identity job receives `id-token: write`. Its preflight requires
an operator readiness attestation before entering `sandbox`. The GitHub
environment did not exist when inspected and is an external prerequisite, so
this repository does not claim that branch limits or review protection exist.

## Implemented sandbox architecture

```mermaid
flowchart LR
  User[HTTP client] -->|TCP 80| ALBSG[ALB security group]
  ALBSG --> ALB[Application Load Balancer]
  ALB -->|TCP 8080| TaskSG[Task security group]
  TaskSG --> Task[ECS Fargate task]
  Task -->|HTTPS| ECR[Amazon ECR and image layers]
  Task -->|HTTPS| Logs[CloudWatch Logs]

  subgraph VPC[VPC in two Availability Zones]
    ALB
    Task
  end
```

The VPC has DNS support and hostnames, two `/24` public subnets in distinct
Availability Zones, one internet gateway, one public route table, one default
IPv4 route, and an association for each subnet. There is no NAT gateway. ECS
assigns each sandbox task a public IPv4 address for outbound traffic; subnet
automatic public-address assignment remains disabled.

## Resource inventory

With `deployment_enabled=true`, Terraform represents 28 resource instances:

| Boundary | Resources |
| --- | --- |
| Network | 1 VPC, 2 public subnets, 1 internet gateway, 1 route table, 1 default route, 2 route-table associations |
| Network security | 2 security groups and 6 standalone ingress or egress rules |
| Registry | 1 ECR repository and 1 lifecycle policy |
| Runtime IAM | 2 roles and 1 inline execution policy |
| Entry point | 1 ALB, 1 IP target group, and 1 HTTP listener |
| Compute | 1 ECS cluster, 1 Fargate task definition, and 1 ECS service |
| Observability | 1 CloudWatch log group |

## Request, image-pull, and logging paths

The exact request path is:

```text
internet TCP/80
-> ALB security group
-> HTTP listener
-> IP target group TCP/8080 with GET /ready health checks
-> task security group allowing TCP/8080 only from the ALB security group
-> non-root application container
```

No task ingress rule contains a public CIDR. SSH, administrative ports, ECS
Exec, and unrestricted security-group egress are absent.

The image-pull path is:

```text
ECS agent using the task execution role
-> ecr:GetAuthorizationToken on Resource "*"
-> BatchCheckLayerAvailability, GetDownloadUrlForLayer, and BatchGetImage
   on the project ECR repository
-> task ENI TCP/443 through its public IPv4 address and internet gateway
-> ECR and signed image-layer endpoints
```

`ecr:GetAuthorizationToken` cannot be resource-scoped by AWS. All repository
read actions are limited to the project repository ARN.

The logging path is:

```text
application structured JSON on stdout/stderr
-> ECS awslogs driver
-> execution-role CreateLogStream and PutLogEvents
-> project CloudWatch log group
```

Log permissions are scoped to streams under that log group. Retention defaults
to seven days, and the log group is disposable with the sandbox.

## Security and IAM boundaries

- The internet crosses only the sandbox ALB on TCP port 80.
- ALB egress is only TCP port 8080 to the task security group.
- Task ingress is only TCP port 8080 from the ALB security group.
- Task egress is TCP port 443 to public endpoints and TCP or UDP port 53 to the
  VPC resolver. Public HTTPS egress is the documented exception required by the
  no-NAT sandbox.
- Both ECS roles trust only `ecs-tasks.amazonaws.com`.
- The task execution role has only ECR-pull and log-delivery actions.
- The application task role has no policies because the API uses no AWS API.
- The container runs as UID 1000 with a read-only root filesystem, no
  privileged mode, and all Linux capabilities dropped.
- The task definition accepts only digest-form image references and explicitly
  selects Linux on X86_64, Fargate, `awsvpc`, 0.25 vCPU, and 0.5 GiB defaults.
- The service uses one task by default, two subnets, Fargate platform `1.4.0`,
  a deployment circuit breaker, and automatic rollback.

## Cost gate and sandbox cost model

Every runtime module uses `deployment_enabled`; every bootstrap module uses
`bootstrap_enabled`. Both default to `false`, disabled outputs are null or
empty, and JSON checks reject any resource change. Local plans use non-secret,
process-local provider placeholders because the AWS provider SDK requires a
credential-shaped value. Provider validation, metadata lookup, account lookup,
refresh, and all resource creation remain disabled.

The enabled sandbox cost equation is:

```text
Fargate vCPU-seconds + Fargate GB-seconds
+ ALB-hours + LCUs + public IPv4
+ ECR storage and requests + CloudWatch log ingestion and storage
+ data transfer
```

The one-task 0.25-vCPU/0.5-GiB defaults and seven-day log retention reduce cost.
The ALB and public IPv4 addresses still have standing charges while deployed.
ECR lifecycle rules expire untagged images after seven days and retain at most
30 images. Repository force deletion is disabled by default.

NAT gateways are deferred because their hourly and per-GB charges are poor
defaults for a disposable exercise. The task HTTPS rule is consequently broad
by destination but narrow by port. Reconsider NAT versus VPC endpoints with a
traffic and availability estimate before production.

## Deferred production architecture

This sandbox is intentionally not production-ready. Production requires:

- private application subnets and redundant reviewed egress;
- ACM-managed TLS, DNS ownership review, HTTPS redirect, and certificate
  renewal ownership;
- ALB access logs and a WAF and rate-control decision;
- capacity, autoscaling, dashboards, alarms, notification, and SLO decisions;
- operational bootstrap and migration of the represented remote state and OIDC
  foundation, plus approved plan/apply/destroy workflows and drift controls;
- a build-once workflow that scans, attests, pushes, and deploys one digest;
- budget alerts and an operationally tested rollback and recovery path.

TLS is deferred because this slice has neither an owned DNS name nor ACM
certificate lifecycle. The HTTP listener is acceptable only for the disposable
sandbox and has a time-bounded Trivy exception.

## Threat model

| Threat | Current control | Residual risk |
| --- | --- | --- |
| Public state exposure | Full public-access block, ownership enforcement, no public allow | Controls are represented but not deployed |
| State interception | TLS-only bucket policy | A misconfigured external client could still fail closed |
| State loss | Versioning and 90-day noncurrent retention | Recovery is not operationally tested |
| Concurrent writes | Native S3 lockfile | Orphaned locks still require operator judgment |
| Lock tampering | Exact lockfile object permissions | Trusted state sessions can remove their own lock |
| State deletion | No `DeleteObject` on the state object | An AWS administrator remains outside this role boundary |
| OIDC confused deputy | Exact audience and exact subject | Trusted workflow compromise remains possible |
| Repository rename ambiguity | Verified immutable owner and repository IDs | GitHub configuration drift could invalidate trust |
| Untrusted PR assumes AWS role | Manual workflow and required protected environment | Environment protection is not yet configured |
| OIDC token theft | 15-minute smoke session and no token logging | A stolen live token remains usable until expiry |
| Shared provider deletion | External-provider reference mode | Account administrators own shared-provider availability |
| Bootstrap state compromise | Human-only bootstrap state boundary | Local state needs careful temporary protection |
| Workflow permission escalation | Job-level `id-token: write` only | A malicious trusted workflow change needs repository review controls |
| Direct task compromise | No public task ingress; ALB-to-task SG reference | Public task IP still reaches approved outbound destinations |
| Supply-chain tampering | Digest-only input and immutable ECR tags | Image publication and attestation are not implemented |
| Destructive deployment | No apply or destroy workflow exists | Manual out-of-band operations could bypass controls |
