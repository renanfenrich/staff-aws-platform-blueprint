# Repository context

- Product: public staff-level AWS platform portfolio blueprint.
- Runtime: Node.js 24 LTS HTTP API with no production npm dependencies.
- Implemented AWS graph: disposable two-AZ public sandbox with ALB, ECR, ECS
  Fargate, separate runtime roles and security groups, and CloudWatch logs.
- Safety gate: `deployment_enabled=false`; the local plan must contain zero AWS
  resource changes and make no AWS API request.
- Enabled validation: Terraform native tests use a mock AWS provider and the
  Trivy configuration scan uses `tests/security.tfvars`.
- Runtime network: tasks receive public IPv4 addresses for egress but accept
  application traffic only from the ALB security group.
- Runtime IAM: execution role pulls only from the project ECR repository and
  writes only to the project log group; the application role is empty.
- Artifact contract: ECS accepts only immutable digest-form image references;
  no build or push workflow exists yet.
- Provisioning: Terraform only; no ad hoc console changes.
- Delivery target: GitHub Actions with AWS OIDC; OIDC, remote state, plan,
  apply, destroy, and promotion remain deferred.
- Environments: disposable sandbox graph only; production is documented but
  rejected by the public-task network profile.
- Base branch: `develop`; stable releases promote to `main`.

Read `docs/architecture.md` and `docs/production-readiness.md` before changing
infrastructure boundaries.
