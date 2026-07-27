# Operational runbooks

These runbooks describe the target controlled workflows. They are not
executable until the production-readiness analysis marks their implementation
complete.

## Sandbox deployment

1. Confirm the change is merged to `develop`, CI and security checks are green,
   and the image digest has a passing scan and SBOM.
2. Open the manual sandbox plan workflow with `deployment_enabled=true`.
3. Review resource count, replacements, IAM changes, public exposure, estimated
   cost, environment, and mandatory tags.
4. Approve the GitHub `sandbox` environment.
5. Apply the exact reviewed plan using OIDC. Never provide AWS access keys.
6. Verify `/health`, `/ready`, the example endpoint, alarms, and structured
   logs.
7. Record the image digest and Terraform revision in the deployment summary.
8. Run the explicit destroy workflow when the exercise ends.

The foundation slice has no apply workflow. Any attempt to deploy it manually
is outside the supported path.

## Explicit sandbox destroy

1. Select the exact `sandbox` environment and type its confirmation phrase.
2. Acquire the remote state lock and generate a destroy plan.
3. Review the target account, region, retained data, and resource list.
4. Approve through the protected environment.
5. Apply only the saved destroy plan.
6. Confirm state contains no managed sandbox resources and check for known
   residual charges such as logs, ECR images, snapshots, or retained EFS data.

Production destroy is not a supported workflow.

## Rollback

1. Stop promotion and determine whether the failure is application or
   infrastructure related.
2. For an application regression, redeploy the previous known-good image
   digest. Do not rebuild the old source.
3. For infrastructure, revert the reviewed Terraform change and generate a new
   plan. Never reuse an obsolete plan.
4. Verify target health, error rate, latency, task count, and logs.
5. Preserve evidence and open a follow-up for the root cause.

Database rollback is outside the current stateless profile. A future persistence
profile must define forward-compatible migrations before it is production-ready.

## Incident response

1. Declare severity, incident lead, communication channel, and timeline.
2. Protect people and data first: restrict traffic, revoke the OIDC session path,
   or scale down only when the impact is understood.
3. Capture CloudTrail, ECS events, task definitions, image digests, ALB access
   data, application logs, alarms, and the last Terraform plan.
4. Contain with the smallest reversible change. Do not edit managed resources
   in the console without recording drift.
5. Recover using a known-good image and reviewed Terraform plan.
6. Verify security boundaries, service indicators, and data integrity.
7. Complete a blameless review with owned corrective actions.

For suspected credential exposure, revoke affected sessions and credentials,
preserve audit evidence, rotate downstream secrets, and search logs and commit
history before restoring deployment access.

## Disaster recovery assumptions

- The API is stateless by default; replacement tasks recover from the image and
  configuration.
- Terraform code and versioned remote state are the infrastructure recovery
  sources.
- ECR image retention must preserve promoted digests.
- The initial target is single-region, multi-AZ. Region loss requires
  reprovisioning in an approved alternate region and DNS failover performed by
  an operator.
- RTO and RPO are not yet business-approved. The stateless target assumption is
  RPO zero for application data because the service owns none.
- EFS, databases, cross-region state replication, and automated DNS failover
  require separate recovery designs and tested exercises.

Run a sandbox restore exercise before claiming production readiness.
