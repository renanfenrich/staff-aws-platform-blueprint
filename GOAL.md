# Goal

Build a production-oriented AWS platform blueprint for a small containerized
API, delivered through Terraform and GitHub Actions.

## Current slice: cost-gated AWS runtime foundation

Deliver a deployable Terraform graph for:

- a two-AZ public sandbox VPC;
- separate ALB and task security boundaries;
- an internet-facing HTTP ALB;
- ECR, ECS Fargate, runtime IAM, and bounded CloudWatch logs;
- a default-disabled, credential-free zero-resource plan;
- mock-provider tests of the enabled graph;
- accurate sandbox and production-gap documentation.

## Scope boundary

This slice does not create AWS resources. OIDC, remote state, apply and destroy
workflows, image publishing, TLS, DNS, WAF, private production networking,
budgets, alarms, autoscaling, persistence, and production remain planned work.

## Completion evidence

- `make validate`
- `make tf-plan`
- `make tf-test`
- `make security`
- `git diff --check`
- reviewed diff with no credentials, public task ingress, mutable images, or
  unpinned automation
