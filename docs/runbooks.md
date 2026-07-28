# Operational runbooks

These runbooks describe controlled future workflows. Terraform represents AWS
OIDC and remote-state infrastructure, but none exists and no state has been
migrated. The repository has no image publication, plan, apply, deployment,
promotion, or destroy workflow. Do not substitute ad hoc Terraform or console
changes.

## External GitHub sandbox prerequisites

Before any OIDC run, a repository administrator must:

1. Create an environment named exactly `sandbox`.
2. Limit deployment branches to `develop`.
3. Add a required reviewer where the repository plan supports it.
4. Store `AWS_STATE_ROLE_ARN`, `AWS_REGION`, and `TF_STATE_BUCKET` as
   non-secret environment variables.
5. Store no AWS access keys in repository, environment, organization, or action
   secrets.
6. Set repository variable `AWS_OIDC_SANDBOX_READY=true` only after the AWS
   bootstrap and all environment controls are independently verified.

The environment endpoint returned 404 on 2026-07-27. Referencing `sandbox` in a
workflow is not evidence that these controls exist. Pull requests must never
trigger AWS authentication.

## Future two-phase state and OIDC bootstrap

Do not execute this procedure without a recorded maintenance window, exact
account approval, reviewed cost, and explicit apply and migration approvals.

### Phase 1: create the foundation from protected local state

1. Obtain a short-lived human operator AWS session. Do not use or store an
   access key in GitHub.
2. Run `aws sts get-caller-identity`, compare the account ID with the approval,
   and stop on any mismatch.
3. Copy `infra/bootstrap/terraform.tfvars.example` to an untracked local file,
   select a reviewed globally unique bucket, and set `bootstrap_enabled=true`.
4. Run `make bootstrap-init`, create a saved bootstrap plan with refresh
   enabled, and review all ten resources, account, region, tags, policies,
   bucket name, and any existing-provider choice.
5. Obtain explicit bootstrap apply approval and apply only that saved plan.
6. Verify bucket ownership, public-access block, versioning, AES-256 default
   encryption, TLS deny, lifecycle, and accidental-destroy protection.
7. Verify the provider URL and audience, exact trust `aud` and `sub`, one-hour
   role maximum, and state-role permission matrix. If the provider already
   exists, supply its ARN and confirm Terraform creates and manages no provider.
8. Configure the protected GitHub environment prerequisites above, then run
   `.github/workflows/aws-oidc-smoke.yml` manually. Record identity and bucket
   control evidence without recording tokens or credentials.

### Phase 2: migrate and initialize state

1. Preserve an encrypted backup of the local bootstrap state. In a separate
   reviewed change, add the partial S3 backend to the bootstrap root with
   `encrypt=true` and `use_lockfile=true`, and prepare an untracked backend
   config using
   `staff-aws-platform-blueprint/bootstrap/terraform.tfstate`.
2. With the same verified human session, run `terraform init -migrate-state`
    for the bootstrap root and explicitly approve only the intended local-to-S3
    migration.
3. Verify bootstrap state and its version in S3, then initialize the runtime
    root with
    `make tf-init-remote BACKEND_CONFIG=infra/terraform/backend.hcl`, using the
    sandbox key from the committed example and process-environment credentials.
4. Prove native locking on each key through a controlled contention test.
    Confirm `.tflock` creation and release without changing managed resources.
5. Record remote-state reads, versions, recovery evidence, lock evidence, exact
    role, account, region, and repository settings. Securely delete temporary
    local state copies only after remote reads and recovery are independently
    verified.
6. Reconfirm that GitHub contains no AWS access key, secret key, session token,
    backend credentials, local state, or plan file.

Never pass credentials through `-backend-config`. Never manually delete a lock
object without proving that no Terraform process owns it.

## Bootstrap and migration rollback

- **Failed bootstrap apply:** preserve local state and the saved plan, stop,
  inspect the next refresh-enabled plan, and obtain new approval before any
  retry or cleanup.
- **Partial bucket controls:** stop state writes, complete or repair ownership,
  public access, encryption, versioning, policy, and lifecycle from the reviewed
  local state. Do not migrate into a partially protected bucket.
- **Incorrect OIDC trust:** unset the readiness attestation, stop smoke runs,
  repair the exact `StringEquals` conditions, and refuse wildcard fallback.
- **Failed migration:** preserve every local copy and S3 version. Do not delete
  either source; reinitialize only after comparing serial, lineage, and object
  versions.
- **Orphaned `.tflock`:** verify workflows, local processes, session ownership,
  and timestamps. Use `terraform force-unlock` with the exact lock ID only when
  no process owns it; do not delete the object casually.
- **Accidental local-state deletion:** stop Terraform and restore the protected
  local backup or verified S3 version before any plan.
- **Bucket name collision:** choose a new approved globally unique name,
  regenerate the plan, and repeat review; never adopt an unknown bucket.
- **Existing shared OIDC provider:** set its validated ARN and replan. Never
  import, replace, modify, or delete the shared provider in this root.

## Local runtime-foundation validation

1. Run `make validate`.
2. Confirm `make tf-plan` reports zero AWS resource changes.
3. Confirm `make tf-test` reports all mock-provider tests passing.
4. Confirm `make bootstrap-plan-disabled` reports zero AWS resource changes.
5. Confirm `make bootstrap-test` passes all mock-provider security assertions.
6. Run `make security` and review any time-bounded exception in
   `.trivyignore.yaml`.
7. Run `git diff --check`.
8. Inspect the full Terraform diff for public state, missing encryption or
   versioning, wildcard trust, broad S3 actions, bootstrap-state access,
   credential patterns, generated plans or state, and unsafe defaults.

These steps use no AWS credentials and create no AWS resources.

## Prerequisites for the first sandbox apply

Do not proceed until every item is complete:

1. An exact sandbox account and `us-east-1` Availability Zones are approved.
2. Encrypted versioned remote state and locking are bootstrapped.
3. GitHub OIDC trust is limited to this repository and protected sandbox
   environment.
4. A build workflow has built once, scanned, attested, and pushed the API image.
5. The selected image digest, not a mutable tag, is recorded for Terraform.
6. Plan, apply, and destroy workflows use separate least-privilege permissions,
   approvals, exact artifacts, and concurrency controls.
7. Budget alerts, operational alarms, and a notification recipient are tested.
8. Standing ALB and public IPv4 costs and Trivy exceptions are accepted.
9. A maintenance window, smoke test, rollback owner, and destroy deadline are
   recorded.

## Future sandbox deployment

1. Confirm the change is merged to `develop` and all required checks are green.
2. Select the approved image digest produced by the build-once workflow.
3. Run the future manual sandbox plan with `deployment_enabled=true`.
4. Review all additions, replacements, IAM changes, public exposure, mandatory
   tags, image digest, environment, region, and estimated cost.
5. Approve the protected sandbox environment.
6. Apply only the exact reviewed plan using GitHub OIDC.
7. Verify the ALB request path, `/health`, `/ready`, the example endpoint,
   target health, task placement across both subnets, and structured logs.
8. Confirm tasks have no public inbound security-group rule.
9. Record the Terraform revision, plan identifier, task definition, image
   digest, ALB address, validation evidence, and destroy deadline.
10. Destroy the sandbox through the approved workflow when the exercise ends.

## Roll back a bad Terraform change

1. Stop further plans and deployments; preserve the failed plan, ECS events,
   task definition, target health, and application logs.
2. Identify the last reviewed Terraform revision and image digest.
3. Revert the faulty Terraform commit through a pull request.
4. Generate a new plan from the revert. Never reuse the old plan.
5. Review replacements, deletions, IAM changes, and any retained ECR or log
   data before approval.
6. Apply only the newly reviewed plan through the protected environment.
7. Verify target health, task count, request behavior, and logs.
8. If the infrastructure is healthy and only the application regressed, deploy
   the previous known-good digest without rebuilding it.
9. Record recovery evidence and open a root-cause follow-up.

If the new plan proposes destructive replacement of retained data or a broader
security boundary, stop for explicit approval. No persistence exists in this
profile, but remote state and ECR contents still require deliberate review.

## Future explicit sandbox destroy

1. Select the exact sandbox environment and enter its confirmation phrase.
2. Acquire the remote state lock and generate a destroy plan.
3. Review the target account, region, resources, retained images and logs, and
   expected residual charges.
4. Approve through the protected sandbox environment.
5. Apply only the saved destroy plan.
6. Confirm state has no managed sandbox resources.
7. Check for residual ECR images, log groups, load balancers, public IPv4
   addresses, and other chargeable resources.

Production destroy is not a supported workflow.

## Incident response

1. Declare severity, incident lead, communication channel, and timeline.
2. Protect people and data first; restrict ALB traffic or stop deployment only
   when the impact is understood.
3. Capture CloudTrail, ECS events, task definitions, image digests, target
   health, application logs, alarms, and the last Terraform plan.
4. Contain with the smallest reversible reviewed change. Record any emergency
   console action as drift.
5. Recover with a known-good digest and reviewed Terraform plan.
6. Verify security-group and IAM boundaries, service indicators, and costs.
7. Complete a blameless review with owned corrective actions.

For suspected credential exposure, revoke affected sessions, preserve evidence,
rotate downstream secrets, and search logs and commit history before restoring
deployment access.

## Disaster recovery assumptions

- The API is stateless; replacement tasks recover from the image and
  configuration.
- Terraform code and future versioned remote state are the infrastructure
  recovery sources.
- ECR retention must preserve promoted digests.
- The target is single-region and multi-AZ. Region loss needs reprovisioning in
  an approved alternate region and future operator-controlled DNS failover.
- RTO and RPO are not business-approved. The stateless application-data target
  is RPO zero because the service owns no durable data.

Run a sandbox restore exercise before making any production-readiness claim.
