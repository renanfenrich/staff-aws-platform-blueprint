# Repository context

- Product: public staff-level AWS platform portfolio blueprint.
- Runtime: Node.js 24 LTS HTTP API with no production npm dependencies.
- Implemented AWS boundaries: a durable bootstrap-owned ECR repository and a
  disposable two-AZ public sandbox with ALB, ECS Fargate, separate runtime roles
  and security groups, and CloudWatch logs.
- Safety gate: `deployment_enabled=false`; the local plan must contain zero AWS
  resource changes and make no AWS API request.
- Bootstrap: isolated `infra/bootstrap` root with `bootstrap_enabled=false`;
  disabled planning is offline and represents zero resources. Enabled mock
  inventory is 14 resources with a created OIDC provider or 13 with an existing
  provider.
- State foundation: one SSE-S3 encrypted, versioned, ownership-enforced bucket
  with full public-access block, TLS-only policy, 90-day noncurrent retention,
  and native S3 lockfiles. The graph has only mock-provider evidence.
- State keys: human-controlled bootstrap state uses
  `staff-aws-platform-blueprint/bootstrap/terraform.tfstate`; the GitHub role
  accesses only `staff-aws-platform-blueprint/sandbox/terraform.tfstate` and
  its `.tflock` object.
- GitHub OIDC: exact subject
  `repo:renanfenrich@1413054/staff-aws-platform-blueprint@1314297578:environment:sandbox`;
  state access is not a workload plan or deployment role.
- Enabled validation: Terraform native tests use a mock AWS provider and the
  Trivy configuration scan uses `tests/security.tfvars`.
- Runtime network: tasks receive public IPv4 addresses for egress but accept
  application traffic only from the ALB security group.
- Runtime IAM: execution role pulls only from the project ECR repository and
  writes only to the project log group; the application role is empty.
- Artifact ownership: bootstrap owns an immutable, scan-on-push, SSE-S3 ECR
  repository with `prevent_destroy`, no force deletion, and a lifecycle rule
  retaining the newest 30 `git-` subject images without generic untagged cleanup.
- Publisher IAM: a separate OIDC role can authenticate, publish, inspect, scan,
  and verify only the project repository; it has no deletion, repository
  management, state, ECS, EC2, IAM mutation, secret, or role-chaining action.
- Artifact contract: manual publication builds exactly once for Linux X86_64,
  scans and creates an SPDX SBOM before AWS authentication, transfers a
  checksummed archive, and defines digest-bound provenance and SBOM
  attestations. The workflow has not run.
- Runtime image contract: the 26-resource enabled graph consumes an explicit
  external repository ARN and URL plus that exact URL at a `sha256` digest.
- Provisioning: Terraform only; no ad hoc console changes.
- Delivery target: GitHub Actions with AWS OIDC. Manual identity smoke and
  image-publication workflows exist; bootstrap execution, actual image
  publication, state migration, runtime initialization, plan, apply, destroy,
  and promotion remain deferred.
- Environments: disposable sandbox graph only; production is documented but
  rejected by the public-task network profile.
- Base branch: `develop`; stable releases promote to `main`.
- External boundary: the `sandbox` GitHub environment returned 404 during this
  work and was not created. Protection, four non-secret publication variables,
  two readiness variables, ECR lifecycle preview, bootstrap apply, OIDC smoke,
  ECR scan behavior, and attestation verification remain operator prerequisites.

Read `docs/architecture.md` and `docs/production-readiness.md` before changing
infrastructure boundaries.
