# Operational runbooks

These runbooks describe controlled future workflows. The repository currently
has no AWS OIDC, remote state, image publication, apply, deployment, promotion,
or destroy workflow. Do not substitute manual Terraform or console changes.

## Local runtime-foundation validation

1. Run `make validate`.
2. Confirm `make tf-plan` reports zero AWS resource changes.
3. Confirm `make tf-test` reports all mock-provider tests passing.
4. Run `make security` and review any time-bounded exception in
   `.trivyignore.yaml`.
5. Run `git diff --check`.
6. Inspect the full Terraform diff for resource counts, public paths, IAM
   actions, tags, mutable images, generated plans or state, and unsafe defaults.

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
