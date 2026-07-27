# ADR 0002: Default to stateless tasks

- Status: Accepted
- Date: 2026-07-27

## Context

Fargate tasks are replaceable and their local filesystems are ephemeral. The
example API does not need durable state, while persistent storage adds backup,
security, availability, recovery, and cost obligations.

## Decision

Keep the default persistence profile as `none`. Configuration enters through
validated environment variables, logs leave through standard output, and the
application writes no local state. A future optional `efs` profile may mount an
encrypted access point only after its recovery and cost controls are defined.

## Consequences

Tasks can run with a read-only root filesystem and roll back by image digest.
The API cannot support durable user data in its current form. EFS is not a
substitute for a transactional database; any future data requirement must select
storage from access, consistency, RPO, and RTO needs rather than convenience.
