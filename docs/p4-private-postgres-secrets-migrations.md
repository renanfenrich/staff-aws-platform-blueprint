# P4 private PostgreSQL, Secrets Manager, and migrations

P4 represents, but does not deploy, a private PostgreSQL 17 persistence path.
Two isolated database subnets use `10.42.20.0/24` and `10.42.21.0/24`, one in
each configured Availability Zone. Their explicit route tables have no default,
internet, NAT, S3, or interface-endpoint route.

The RDS sandbox model uses private encrypted 20 GiB gp3 PostgreSQL 17.11 with
one-day backups, no Multi-AZ, no Performance Insights, and no enhanced
monitoring. RDS owns its single master secret through
`manage_master_user_password = true`; Terraform exposes only that ARN.
`rds.force_ssl = 1` is explicit. The image obtains the official RDS CA bundle
at build time with a pinned SHA-256; certificate validation stays enabled.

The fourth interface endpoint is `com.amazonaws.<region>.secretsmanager` with
private DNS, the existing endpoint security group, and application subnets.
The task role has only `secretsmanager:GetSecretValue` for the exact RDS secret;
the execution role remains ECR pull and log delivery only.

Local/test use `DATABASE_URL`. Production rejects that mode and uses RDS
metadata, secret ARN, region, and CA path. New PostgreSQL connections retrieve
the password through the node-postgres callback without an indefinite cache.
Errors never include a secret payload or password.

The migration task is a task definition, not a service. It uses the API image
digest, roles, metadata, TLS, logging, UID 1000, read-only root filesystem, and
dropped capabilities; it runs `node dist/db/migrate.js`. Terraform never runs
it. P8 must run it, wait for `STOPPED`, require exit code zero, then roll out
the backend service.

The enabled runtime count is 51, from P3's 39: network 29 to 36, IAM 3 to 4,
plus database 3 and migration 1. Mock evidence proves graph construction only,
not regional engine availability, RDS connectivity, retrieval/rotation, task
execution, or endpoint connectivity. Future live costs include RDS, its secret,
four endpoint services, ALB, CloudWatch, and Fargate. P4 is not production-ready:
production deletion protection and final snapshot policy remain gaps.
