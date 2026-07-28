import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const read = (path) => readFileSync(path, "utf8");
const workflowDirectory = ".github/workflows";
const workflows = Object.fromEntries(
  readdirSync(workflowDirectory)
    .filter((name) => name.endsWith(".yml") || name.endsWith(".yaml"))
    .map((name) => [name, read(join(workflowDirectory, name))]),
);

const smoke = workflows["aws-oidc-smoke.yml"];
assert(smoke, "AWS OIDC smoke workflow is missing.");
assert.match(smoke, /^on:\n {2}workflow_dispatch:\s*$/m);
assert.doesNotMatch(smoke, /^\s+(push|pull_request|pull_request_target):/m);
assert.match(
  smoke,
  /environment_name: \$\{\{ steps\.readiness\.outputs\.environment_name \}\}/,
);
assert.match(smoke, /name: \$\{\{ needs\.preflight\.outputs\.environment_name \}\}/);
assert.match(smoke, /^\s+deployment: false$/m);
assert.doesNotMatch(smoke, /^\s+environment: sandbox$/m);
assert.equal(
  [...smoke.matchAll(/^\s+id-token: write$/gm)].length,
  1,
  "Only the identity job may request an OIDC token.",
);
assert.match(
  smoke,
  /uses: aws-actions\/configure-aws-credentials@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+/,
);
assert.match(smoke, /role-duration-seconds: 900/);
assert.match(smoke, /audience: sts\.amazonaws\.com/);
assert.match(smoke, /role-session-name: staff-state-\$\{\{ github\.run_id \}\}/);
assert.match(smoke, /AWS_OIDC_SANDBOX_READY/);
assert.match(smoke, /echo "environment_name=sandbox" >> "\$\{GITHUB_OUTPUT\}"/);
assert.doesNotMatch(smoke, /secrets\.(AWS|TF_STATE)/);
assert.doesNotMatch(smoke, /AWS_(ACCESS_KEY_ID|SECRET_ACCESS_KEY|SESSION_TOKEN)/);

const nonAwsWorkflows = Object.entries(workflows)
  .filter(([name]) => name !== "aws-oidc-smoke.yml" && name !== "publish-image.yml")
  .map(([, contents]) => contents)
  .join("\n");
assert.equal(
  [...nonAwsWorkflows.matchAll(/^\s+id-token: write$/gm)].length,
  1,
  "Existing workflows must retain only the push-only provenance OIDC permission.",
);
assert.equal([...workflows["ci.yml"].matchAll(/^\s+id-token: write$/gm)].length, 1);
assert.match(
  workflows["ci.yml"],
  /provenance:[\s\S]+?if: github\.event_name == 'push'[\s\S]+?id-token: write/,
);
for (const [name, contents] of Object.entries(workflows)) {
  if (
    name !== "aws-oidc-smoke.yml" &&
    name !== "publish-image.yml" &&
    name !== "ci.yml"
  ) {
    assert.doesNotMatch(contents, /^\s+id-token: write$/m);
  }
}
assert.doesNotMatch(nonAwsWorkflows, /secrets\.AWS/);

const runtimeBackend = read("infra/terraform/backend.tf");
assert.match(runtimeBackend, /backend "s3"/);
assert.match(runtimeBackend, /encrypt\s+= true/);
assert.match(runtimeBackend, /use_lockfile\s+= true/);
assert.doesNotMatch(
  runtimeBackend,
  /(bucket|account_id|role_arn|access_key|secret_key|session_token)\s*=/,
);

const backendExample = read("infra/terraform/backend.hcl.example");
assert.match(
  backendExample,
  /key\s+= "staff-aws-platform-blueprint\/sandbox\/terraform\.tfstate"/,
);
assert.doesNotMatch(
  backendExample,
  /(access_key|secret_key|session_token|role_arn)\s*=/,
);

const oidcModule = read("infra/bootstrap/modules/github-oidc/main.tf");
assert.match(oidcModule, /https:\/\/token\.actions\.githubusercontent\.com/);
assert.match(oidcModule, /"token\.actions\.githubusercontent\.com:aud"/);
assert.match(oidcModule, /"token\.actions\.githubusercontent\.com:sub"/);
assert.doesNotMatch(oidcModule, /StringLike/);
assert.doesNotMatch(oidcModule, /thumbprint_list/);
assert.doesNotMatch(oidcModule, /"(iam|ecs|ec2|ecr|logs|cloudwatch):[A-Za-z*]+"/);
assert.doesNotMatch(oidcModule, /"s3:\*"/);
assert.doesNotMatch(oidcModule, /\/bootstrap\//);

const stateModule = read("infra/bootstrap/modules/state/main.tf");
assert.match(stateModule, /prevent_destroy = true/);
assert.match(stateModule, /object_ownership = "BucketOwnerEnforced"/);
assert.match(stateModule, /aws:SecureTransport/);
assert.match(stateModule, /sse_algorithm = "AES256"/);
assert.doesNotMatch(stateModule, /^\s+expiration\s+\{/m);
assert.doesNotMatch(stateModule, /aws_s3_bucket_(acl|website|object_lock|replication)/);

console.log("AWS backend, bootstrap, OIDC trust, and smoke workflow checks passed.");
