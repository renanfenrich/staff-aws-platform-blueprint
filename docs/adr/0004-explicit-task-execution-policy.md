# ADR 0004: Use an explicit ECS task execution policy

- Status: Accepted
- Date: 2026-07-27

## Context

The AWS-managed ECS task execution policy is convenient but grants repository
and log actions with broad resources. This workload pulls from one ECR
repository and writes to one CloudWatch log group. Its application currently
uses no AWS API.

## Decision

Use a small inline policy on the execution role:

- `ecr:GetAuthorizationToken` on `"*"` because AWS does not support resource
  scoping for that action;
- ECR layer and manifest reads on the project repository ARN;
- log stream creation and event publication on streams under the project log
  group.

Create a separate application role with the ECS tasks trust policy and no
permissions. Both roles trust only `ecs-tasks.amazonaws.com`.

## Consequences

The execution boundary is visible and testable in this repository and avoids a
broad managed policy. Future registries, log destinations, secrets, or
application AWS calls require explicit reviewed policy changes. Inline policy
lifecycle is coupled to this role, which is appropriate for the single-service
module.
