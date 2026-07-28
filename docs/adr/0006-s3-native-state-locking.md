# ADR 0006: Use native S3 state locking

- Status: Accepted
- Date: 2026-07-27

## Context

Terraform needs encrypted remote state, concurrency control, and recoverable
history before any sandbox plan or deployment automation exists. A separate
DynamoDB lock table would add another resource and operating surface when the
pinned Terraform version supports S3 lockfiles.

## Decision

Use the S3 backend with `encrypt = true` and `use_lockfile = true`. Reserve:

- `staff-aws-platform-blueprint/bootstrap/terraform.tfstate`
- `staff-aws-platform-blueprint/bootstrap/terraform.tfstate.tflock`
- `staff-aws-platform-blueprint/sandbox/terraform.tfstate`
- `staff-aws-platform-blueprint/sandbox/terraform.tfstate.tflock`

Enable bucket versioning and retain noncurrent versions for 90 days. Never
expire the current state object. Abort incomplete multipart uploads after seven
days. Permit the GitHub state role to get and put the exact sandbox state
object, but not delete it. Permit get, put, and delete only on its exact lock
object because Terraform must remove a released native lock.

Use SSE-S3 AES-256. It avoids the standing charge of a customer-managed KMS key
for this disposable portfolio sandbox. A dedicated KMS key remains a production
decision. State remains sensitive: default encryption does not replace access
control, TLS, version recovery, or careful output handling.

## Consequences

DynamoDB locking and Object Lock are unnecessary in this slice. S3 versioning
provides recovery evidence but does not prevent an authorized overwrite.
Orphaned locks require ownership verification before `terraform force-unlock`;
operators must never delete `.tflock` objects while a Terraform process may
own them.
