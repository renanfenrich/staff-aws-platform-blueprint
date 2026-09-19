# ADR 0013: Use private ECS application subnets and required VPC endpoints

- Status: Accepted
- Date: 2026-09-18

## Context

The P2 application now requires PostgreSQL through `DATABASE_URL`, but private
database and secret delivery belong to P4. ECS nevertheless needs a narrow,
NAT-free execution path for ECR image pulls and CloudWatch Logs.

## Decision

Keep the ALB in two public subnets. Place ECS tasks in two private application
subnets with `assign_public_ip = false`, one per configured Availability Zone.
Each application subnet receives its own route table with no default route.
Use private-DNS interface endpoints for ECR API, ECR DKR, and CloudWatch Logs,
plus an S3 gateway endpoint associated only with application route tables.
Endpoint names are derived from the configured region: China ECR uses the
`cn.com.amazonaws` prefix. S3 gateway endpoints and Logs use
`com.amazonaws` in every supported partition.

Task TCP/443 egress references the endpoint security group and the S3 managed
prefix list. DNS remains restricted to the VPC resolver. The endpoint SG
accepts TCP/443 only from the task SG and has no broad egress. There is no NAT
gateway, NAT instance, Secrets Manager endpoint, or additional endpoint.

## Consequences

The represented graph removes public task IPs and broad HTTPS egress, while
introducing interface-endpoint per-AZ standing cost after a future deployment.
The S3 gateway endpoint has no hourly endpoint charge. IAM remains the
authorization boundary; endpoint policies retain AWS defaults in P3.

P3 is local Terraform representation and mock-provider evidence only. It does
not prove endpoint connectivity or a deployable application: P4 must supply
private PostgreSQL, Secrets Manager, and the production `DATABASE_URL` contract.
