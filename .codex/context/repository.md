# Repository context

- Product: public staff-level AWS platform portfolio blueprint.
- Runtime: Node.js 24 LTS HTTP API with no production npm dependencies.
- Target: AWS ECS Fargate behind an Application Load Balancer.
- Provisioning: Terraform; no ad hoc console changes.
- Delivery: GitHub Actions with AWS OIDC; no long-lived AWS credentials.
- Environments: disposable sandbox first; production is a documented target,
  not enabled by default.
- Base branch: `develop`; stable releases promote to `main`.

Read `docs/architecture.md` and `docs/production-readiness.md` before changing
infrastructure boundaries.
