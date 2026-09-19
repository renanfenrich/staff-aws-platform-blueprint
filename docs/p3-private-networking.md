# P3 private application networking

P3 changes the represented Terraform network graph and is locally validated
with Terraform 1.15.8 mock-provider tests and credential-free disabled plans.
It performs no AWS deployment or endpoint-connectivity test.

## Topology change

Before P3, the public ALB and ECS tasks used `10.42.0.0/24` and
`10.42.1.0/24`; tasks had public IPs and TCP/443 egress to `0.0.0.0/0`.

After P3, the ALB remains in those two public subnets. ECS uses private
application subnets `10.42.10.0/24` and `10.42.11.0/24`, with
`assign_public_ip = false`. Each application subnet has its own route table
with only the VPC local route and the S3 gateway-endpoint route—no internet or
NAT default route.

The endpoint inventory is ECR API, ECR DKR, and CloudWatch Logs interface
endpoints with private DNS and ENIs in both application subnets, plus an S3
gateway endpoint on application route tables only. A dedicated endpoint SG
accepts task-SG TCP/443 only. Task-SG TCP/443 egress is limited to that SG and
the S3 managed prefix list; DNS is limited to the VPC resolver.

No NAT gateway or NAT instance is represented. Secrets Manager, RDS, a
Secrets Manager endpoint, ACM/TLS, and Cloudflare automation are intentionally
absent. IAM is unchanged: execution-role ECR/Logs actions remain narrow and
the application role remains empty. Endpoint policies stay at AWS defaults, so
IAM—not endpoints—remains the authorization boundary.

Endpoint service names are deterministic and partition-aware: China ECR
interface endpoints use `cn.com.amazonaws.<region>`; China CloudWatch Logs and
the S3 gateway endpoint use `com.amazonaws.<region>`, as S3 does across all
supported partitions. No provider data source or AWS API lookup is used to
resolve these names.

## Evidence and next prerequisite

Interface endpoints have per-AZ/hour standing costs and endpoint data charges
when deployed; the public ALB and CloudWatch also cost money. The S3 gateway
endpoint has no hourly endpoint charge. Nothing is deployed by P3.

P2's `/ready` requires PostgreSQL. P3 therefore does not make the application
live-deployable: P4 must add private PostgreSQL, secret generation and delivery,
the Secrets Manager endpoint and least-privilege IAM, before a real ECS runtime
can start correctly.
