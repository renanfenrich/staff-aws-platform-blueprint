# P5 split frontend and backend ECS services

P5 represents two private Fargate services behind one public HTTP ALB. The
default listener action serves the frontend target group; `/api` and `/api/*`
use the backend target group. Frontend health is `/health`; backend ALB health
remains database-dependent `/ready`, while its container health remains `/health`.

The frontend and backend use distinct security groups. Both may reach private
ECR, Logs, and S3 paths plus the VPC resolver. Only the backend may reach the
database group on PostgreSQL 5432, and the database accepts only that backend
group. There is no frontend-to-backend rule: browser API requests stay relative
and same-origin through the ALB.

The frontend role trusts ECS tasks but has no application permissions. The
backend role has only `secretsmanager:GetSecretValue` for the exact RDS-managed
secret. The execution role is shared and unchanged. The migration definition
uses the backend role and remains one-off and unexecuted; P8 must run it before
any backend rollout.

P5 intentionally retains one transitional immutable image digest for frontend,
backend, and migration. The image contains the backend runtime, migrations, RDS
CA bundle, built Vite frontend, and a dependency-free Node static server. P7,
not P5, will split repositories, publisher roles, workflows, and artifacts.

P4 total was 54. P5 adds eight network instances (a frontend task SG and split
ALB/task endpoint/S3/DNS rules), one empty frontend IAM role, two ALB instances
(backend target group and listener rule), and two ECS instances (frontend task
definition and service): `54 + 13 = 67`. Module totals are network 47, IAM 5,
ALB 5, ECS 5, observability 1, database 3, and migration 1.

No TLS, ACM, Cloudflare, DNS, WAF, extra ECR repository, separate publication
path, live AWS deployment, or state mutation is included. If enabled later,
P5 represents one frontend and one backend Fargate task alongside the existing
ALB, RDS, endpoints, and log group; no price is asserted.
