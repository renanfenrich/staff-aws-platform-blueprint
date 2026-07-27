# ADR 0001: Use ECS Fargate instead of EKS

- Status: Accepted
- Date: 2026-07-27

## Context

The target is one small HTTP API and a portfolio blueprint that should
demonstrate production controls without operating a Kubernetes control plane.

## Decision

Use Amazon ECS on Fargate behind an Application Load Balancer.

## Rationale

- ECS provides task scheduling, service health, rolling deployments, IAM roles,
  and CloudWatch integration with fewer operational layers.
- Fargate removes host patching and idle cluster capacity from this scope.
- EKS would add Kubernetes API, add-on, policy, upgrade, and specialist
  operational responsibilities that one service does not justify.
- The reduced surface makes IAM, networking, cost, and recovery decisions easier
  to review.

## Consequences

The blueprint is AWS-specific and does not demonstrate Kubernetes portability or
its ecosystem. Revisit EKS when multiple teams need a shared platform,
Kubernetes-native APIs are a hard requirement, or workload scale makes its
operating cost and complexity worthwhile.
