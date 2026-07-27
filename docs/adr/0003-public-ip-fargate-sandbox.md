# ADR 0003: Use public-IP Fargate tasks in the disposable sandbox

- Status: Accepted
- Date: 2026-07-27

## Context

Fargate tasks need outbound HTTPS for ECR image layers and CloudWatch Logs. A
NAT gateway adds hourly and per-GB charges that are disproportionate for a
short-lived portfolio sandbox. VPC endpoints also add hourly charges and a
larger policy surface.

## Decision

Place the sandbox service across two public subnets and let ECS assign public
IPv4 addresses to its tasks. Keep subnet automatic public-address assignment
disabled. Give tasks no public inbound rule: application ingress is TCP port
8080 only from the ALB security group. Allow task egress only for DNS to the VPC
resolver and HTTPS to public endpoints.

## Consequences

The sandbox avoids NAT charges but pays for task public IPv4 addresses and has a
broader TCP port 443 destination boundary. The design is sandbox-only and
Terraform rejects the production environment with this network profile.
Production must use private application subnets and select redundant NAT
gateways or VPC endpoints after a traffic, availability, and cost review.
