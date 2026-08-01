import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const read = (path) => readFileSync(path, "utf8");
const makefile = read("Makefile");
const backend = read("infra/bootstrap/backend.tf");
const example = read("infra/bootstrap/backend.hcl.example");
const preflight = read("scripts/bootstrap-state-migration-preflight.sh");
const locking = read("scripts/verify-s3-native-locking.sh");
const bootstrapPlan = read("scripts/bootstrap-plan.sh");
const runtimeBackend = read("infra/terraform/backend.tf");
const runtimeExample = read("infra/terraform/backend.hcl.example");

assert.equal(
  backend.trim(),
  `terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}`,
  "Bootstrap must contain only the reviewed partial S3 backend.",
);
assert.match(example, /bucket\s*=\s*"replace-with-approved-globally-unique-bucket"/);
assert.match(
  example,
  /key\s*=\s*"staff-aws-platform-blueprint\/bootstrap\/terraform\.tfstate"/,
);
assert.doesNotMatch(example, /(access_key|secret_key|session_token|role_arn)\s*=/);
assert.match(
  runtimeExample,
  /staff-aws-platform-blueprint\/sandbox\/terraform\.tfstate/,
);
assert.notEqual(
  "staff-aws-platform-blueprint/bootstrap/terraform.tfstate",
  "staff-aws-platform-blueprint/sandbox/terraform.tfstate",
);
assert.match(runtimeBackend, /encrypt\s+=\s+true/);
assert.match(runtimeBackend, /use_lockfile\s+=\s+true/);

for (const ignored of [
  "infra/bootstrap/backend.hcl",
  "infra/bootstrap/terraform.tfbackend",
  "infra/bootstrap/terraform.tfstate",
  "infra/bootstrap/terraform.tfstate.backup",
  "infra/bootstrap/terraform.tfplan",
  "infra/bootstrap/terraform.tfvars",
  "infra/bootstrap/.terraform",
]) {
  execFileSync("git", ["check-ignore", "-q", "--", ignored]);
}
const tracked = execFileSync("git", ["ls-files"], { encoding: "utf8" });
assert.doesNotMatch(
  tracked,
  /(^|\/)(backend\.hcl|.*\.tfbackend|.*\.tfstate(?:\..*)?|.*\.tfplan|terraform\.tfvars)$/m,
);

assert.match(makefile, /bootstrap-init-local[\s\S]+?init -backend=false -input=false/);
assert.match(makefile, /bootstrap-init: bootstrap-init-local/);
assert.match(makefile, /bootstrap-init-remote:[\s\S]+?BACKEND_CONFIG/);
assert.match(makefile, /bootstrap-init-remote:[\s\S]+?-reconfigure/);
assert.doesNotMatch(makefile, /bootstrap-init-remote:[\s\S]+?-migrate-state/);
assert.match(
  makefile,
  /bootstrap-state-migration-check:[\s\S]+?validate-bootstrap-state-migration\.mjs/,
);
assert.match(makefile, /validate:[\s\S]+?bootstrap-state-migration-check/);
assert.match(makefile, /bootstrap-test:[\s\S]+?! -name terraform\.tfvars/);
assert.match(bootstrapPlan, /init -backend=false -input=false/);
assert.match(bootstrapPlan, /! -name backend\.tf/);
assert.match(bootstrapPlan, /! -name terraform\.tfvars/);

for (const required of [
  "BOOTSTRAP_VAR_FILE",
  "BOOTSTRAP_BACKEND_CONFIG",
  "EXPECTED_AWS_ACCOUNT_ID",
  "EXPECTED_AWS_REGION",
  "aws sts get-caller-identity",
  "get-bucket-versioning",
  "get-bucket-encryption",
  "get-public-access-block",
  "get-bucket-ownership-controls",
  "get-bucket-policy",
  "detailed-exitcode",
]) {
  assert.match(preflight, new RegExp(required.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
}
assert.match(preflight, /set -eu/);
assert.match(preflight, /git check-ignore/);
assert.match(preflight, /git status --porcelain/);
assert.match(preflight, /staff-aws-platform-blueprint\/bootstrap\/terraform\.tfstate/);
assert.doesNotMatch(
  preflight,
  /terraform\s+init\s+-migrate-state|terraform\s+apply|terraform\s+destroy|force-unlock/,
);
assert.doesNotMatch(preflight, /aws\s+s3\s+(rm|cp)|delete-object/);

for (const required of [
  "bootstrap",
  "runtime",
  "EXPECTED_STATE_KEY",
  "terraform.*plan",
  "timeout",
  "\\.tflock",
  "SIGSTOP",
  "SIGCONT",
  "state lock",
]) {
  assert.match(locking, new RegExp(required, "is"));
}
assert.doesNotMatch(
  locking,
  /terraform\s+apply|force-unlock|aws\s+s3\s+rm|delete-object/,
);
assert.doesNotMatch(locking, /rm\s+[^\n]*\.tflock/);
assert.match(locking, /SECOND_PLAN|second_plan|second.*plan/is);
assert.match(locking, /head-object/);

const workflowDirectory = ".github/workflows";
const workflowNames = readdirSync(workflowDirectory).filter((name) =>
  /\.ya?ml$/.test(name),
);
const workflows = workflowNames.map((name) => read(join(workflowDirectory, name)));
const workflowText = workflows.join("\n");
assert.doesNotMatch(
  workflowText,
  /-backend-config|init\s+-migrate-state|terraform\s+apply|terraform\s+destroy/,
);
assert.doesNotMatch(workflowText, /verify-s3-native-locking/);
assert.match(read(".github/workflows/ci.yml"), /bootstrap-state-migration-check/);
assert.doesNotMatch(
  read(".github/workflows/ci.yml"),
  /\baws\s|configure-aws-credentials/,
);

const sourceFiles = [
  "Makefile",
  "infra/bootstrap/backend.tf",
  "infra/bootstrap/backend.hcl.example",
  "scripts/bootstrap-state-migration-preflight.sh",
  "scripts/verify-s3-native-locking.sh",
  "scripts/bootstrap-plan.sh",
  ...workflowNames.map((name) => join(workflowDirectory, name)),
];
for (const path of sourceFiles) {
  const contents = read(path);
  assert.doesNotMatch(contents, /AKIA[0-9A-Z]{16}/, `${path} contains an access key.`);
  assert.doesNotMatch(
    contents,
    /-----BEGIN [A-Z ]+ PRIVATE KEY-----/,
    `${path} contains a private key.`,
  );
  assert.doesNotMatch(
    contents,
    /(?:aws_access_key_id|aws_secret_access_key|session_token)\s*=\s*"(?!credential-free)/i,
    `${path} contains backend credentials.`,
  );
}
assert.doesNotMatch(
  `${makefile}\n${preflight}\n${locking}`,
  /-force-copy|delete-object|force-unlock/,
);

const walk = (directory) =>
  readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      if (
        [
          ".git",
          ".terraform",
          "node_modules",
          ".artifacts",
          "dist",
          "coverage",
        ].includes(entry.name)
      )
        return [];
      return walk(path);
    }
    return entry.name.endsWith(".sh") ? [path] : [];
  });
for (const path of walk("scripts")) {
  const contents = read(path);
  assert.doesNotMatch(contents, /aws\s+s3\s+rm|aws\s+s3api\s+delete-object/);
}

console.log("Bootstrap state migration boundary checks passed.");
