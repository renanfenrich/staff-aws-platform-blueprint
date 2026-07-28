import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";

const read = (path) => readFileSync(path, "utf8");
const workflow = read(".github/workflows/publish-image.yml");

const job = (name) => {
  const match = workflow.match(
    new RegExp(`^  ${name}:\\n([\\s\\S]*?)(?=^  [a-zA-Z0-9_-]+:\\n|(?![\\s\\S]))`, "m"),
  );
  assert(match, `Workflow job ${name} is missing.`);
  return match[0];
};

const preflight = job("preflight");
const build = job("build");
const publish = job("publish");
const permissions = (jobBlock) => {
  const match = jobBlock.match(
    /^ {4}permissions:\n((?:^ {6}[a-z-]+: (?:read|write|none)\n?)+)/m,
  );
  assert(match, "Job permissions block is missing.");
  return match[1]
    .trim()
    .split("\n")
    .map((line) => line.trim());
};

assert.match(workflow, /^on:\n {2}workflow_dispatch:\s*$/m);
assert.doesNotMatch(
  workflow,
  /^\s{2}(push|pull_request|pull_request_target|schedule|workflow_call):/m,
);
assert.match(workflow, /cancel-in-progress: false/);
assert.match(
  workflow,
  /group: publish-image-\$\{\{ github\.repository_id \}\}-\$\{\{ github\.sha \}\}/,
);

assert.deepEqual(permissions(preflight), ["contents: read"]);
assert.doesNotMatch(preflight, /^\s{4}environment:/m);
assert.match(preflight, /GITHUB_REF.*refs\/heads\/develop/);
assert.match(preflight, /AWS_OIDC_SANDBOX_READY/);
assert.match(preflight, /AWS_IMAGE_PUBLISH_READY/);
assert.match(preflight, /environment_name=sandbox.*GITHUB_OUTPUT/);

assert.deepEqual(permissions(build), ["contents: read"]);
assert.doesNotMatch(build, /^\s{6}(id-token|attestations): write$/m);
assert.doesNotMatch(build, /^\s{4}environment:/m);
assert.doesNotMatch(
  build,
  /aws-actions\/|secrets\.AWS|AWS_(ACCESS_KEY_ID|SECRET_ACCESS_KEY|SESSION_TOKEN)/,
);

assert.match(
  publish,
  /environment:\n {6}name: \$\{\{ needs\.preflight\.outputs\.environment_name \}\}\n {6}deployment: false/,
);
assert.deepEqual(permissions(publish), [
  "contents: read",
  "id-token: write",
  "attestations: write",
]);
assert.equal([...workflow.matchAll(/^\s+id-token: write$/gm)].length, 1);
assert.equal([...workflow.matchAll(/^\s+attestations: write$/gm)].length, 1);

const buildCommands = [...workflow.matchAll(/^\s*docker build(?:\s|\\)/gm)];
assert.equal(buildCommands.length, 1, "Publication workflow must build exactly once.");
assert.match(
  build,
  /docker build --platform linux\/amd64 --provenance=false --sbom=false/,
);
assert.doesNotMatch(publish, /^\s*docker build(?:\s|\\)/m);
assert.doesNotMatch(publish, /docker buildx build/);
assert.match(build, /scripts\/image-scan\.sh "\$\{LOCAL_IMAGE\}"/);
assert.match(build, /scripts\/image-sbom\.sh "\$\{LOCAL_IMAGE\}"/);
assert.match(build, /docker save --output transfer\/image\.tar/);
assert.match(publish, /docker load --input transfer\/image\.tar/);

const credentialIndex = publish.indexOf("aws-actions/configure-aws-credentials@");
assert(credentialIndex > 0);
for (const requiredBeforeAuth of [
  "sha256sum --check transfer/image-archive.sha256",
  "expected_sbom_sha256",
  "docker load --input transfer/image.tar",
]) {
  const index = publish.indexOf(requiredBeforeAuth);
  assert(
    index > 0 && index < credentialIndex,
    `${requiredBeforeAuth} must precede AWS authentication.`,
  );
}
assert(
  build.indexOf("scripts/image-scan.sh") < build.indexOf("actions/upload-artifact@"),
);
assert(
  build.indexOf("scripts/image-sbom.sh") < build.indexOf("actions/upload-artifact@"),
);

assert.match(publish, /audience: sts\.amazonaws\.com/);
assert.match(publish, /role-duration-seconds: 900/);
assert.match(publish, /role-skip-session-tagging: true/);
assert.match(publish, /role-session-name: staff-image-\$\{\{ github\.run_id \}\}/);
assert.match(publish, /aws sts get-caller-identity/);
assert.match(publish, /aws ecr describe-repositories/);
assert.match(publish, /imageTagMutability == "IMMUTABLE"/);
assert.match(publish, /imageScanningConfiguration\.scanOnPush == true/);

assert.match(
  workflow,
  /TRACEABILITY_TAG: git-\$\{\{ github\.sha \}\}-\$\{\{ github\.run_id \}\}/,
);
assert.doesNotMatch(workflow, /(^|[^a-z])latest([^a-z]|$)/i);
assert.doesNotMatch(workflow, /TRACEABILITY_TAG:.*(develop|stable)/);
assert.match(publish, /ECR_REPOSITORY_URL.*@\$\{registry_digest\}/);
assert.match(publish, /aws ecr describe-images/);
assert.doesNotMatch(
  publish,
  /describe-image-scan-findings|ecr-scan-results|bounded polling/,
);

const ecrLoginIndex = publish.indexOf("aws-actions/amazon-ecr-login@");
const attestCredentialIndex = publish.indexOf(
  "Isolate ECR credentials for attestation",
);
const firstAttestationIndex = publish.indexOf("uses: actions/attest@");
assert(ecrLoginIndex > 0);
assert(attestCredentialIndex > ecrLoginIndex);
assert(firstAttestationIndex > attestCredentialIndex);
assert.match(publish, /DOCKER_CONFIG=\$\{docker_config\}/);
assert.match(publish, /attest_home=\$\{attest_home\}/);
assert.match(publish, /install -D -m 600 "\$\{DOCKER_CONFIG\}\/config\.json"/);
assert.equal(
  [...publish.matchAll(/HOME: \$\{\{ steps\.configuration\.outputs\.attest_home \}\}/g)]
    .length,
  2,
);
assert.match(
  publish,
  /rm -f "\$\{RUNNER_TEMP\}\/staff-image-docker-config\/config\.json"/,
);
assert.match(
  publish,
  /rm -f "\$\{RUNNER_TEMP\}\/staff-image-attest-home\/.docker\/config\.json"/,
);
assert.doesNotMatch(publish, /rm -f "\$\{HOME\}\/.docker\/config\.json"/);

const attestUses = [
  ...publish.matchAll(/uses: actions\/attest@[0-9a-f]{40} # v4\.2\.0/g),
];
assert.equal(attestUses.length, 2);
assert.equal(
  [...publish.matchAll(/subject-name: \$\{\{ vars\.ECR_REPOSITORY_URL \}\}/g)].length,
  2,
);
assert.equal(
  [...publish.matchAll(/subject-digest: \$\{\{ steps\.resolve\.outputs\.digest \}\}/g)]
    .length,
  2,
);
assert.equal([...publish.matchAll(/push-to-registry: true/g)].length, 2);
assert.equal([...publish.matchAll(/create-storage-record: false/g)].length, 2);
assert.match(publish, /sbom-path: evidence\/sbom\.spdx\.json/);
assert.match(
  publish,
  /gh attestation verify[\s\S]+--repo "renanfenrich\/staff-aws-platform-blueprint"/,
);
assert.match(publish, /--predicate-type "https:\/\/spdx\.dev\/Document\/v2\.3"/);
assert.match(publish, /aws ecr list-image-referrers/);

assert.match(workflow, /retention-days: 1/);
assert.equal([...workflow.matchAll(/retention-days: 14/g)].length, 2);
assert.match(
  workflow,
  /image-archive-\$\{\{ github\.run_id \}\}-\$\{\{ github\.run_attempt \}\}/,
);
assert.match(workflow, /if-no-files-found: error/);

const usesLines = workflow.match(/^\s*uses:\s+.+$/gm) ?? [];
assert(usesLines.length > 0);
for (const line of usesLines) {
  assert.match(line, /@[0-9a-f]{40}(?:\s+#\s+v[0-9].*)?$/);
}

for (const forbidden of [
  /secrets\.(AWS|ECR)/,
  /AWS_(ACCESS_KEY_ID|SECRET_ACCESS_KEY|SESSION_TOKEN)/,
  /ECR_PASSWORD/,
  /terraform\s+(apply|destroy)/i,
  /aws\s+ecs\s+(update|register)/i,
  /aws\s+ecr\s+(delete|batch-delete|put-lifecycle|set-repository-policy)/i,
  /ecr-public/i,
  /docker\.io/i,
  /ghcr\.io/i,
]) {
  assert.doesNotMatch(workflow, forbidden);
}

const runtimeMain = read("infra/terraform/main.tf");
const runtimeVariables = read("infra/terraform/variables.tf");
assert.doesNotMatch(runtimeMain, /module "ecr"/);
assert.doesNotMatch(runtimeMain, /data "aws_ecr_/);
assert.match(runtimeMain, /ecr_repository_arn = var\.ecr_repository_arn/);
assert.match(runtimeVariables, /variable "ecr_repository_arn"/);
assert.match(runtimeVariables, /variable "ecr_repository_url"/);
assert.match(
  runtimeVariables,
  /split\("@", var\.container_image\)\[0\] == var\.ecr_repository_url/,
);
assert(
  !existsSync("infra/terraform/modules/ecr"),
  "Runtime must not retain an ECR module.",
);

const bootstrapMain = read("infra/bootstrap/main.tf");
const ecr = read("infra/bootstrap/modules/ecr/main.tf");
const publisher = read("infra/bootstrap/modules/ecr-publisher/main.tf");
const imageScan = read("scripts/image-scan.sh");
const imageSbom = read("scripts/image-sbom.sh");
assert.match(bootstrapMain, /module "ecr"/);
assert.match(bootstrapMain, /module "ecr_publisher"/);
assert.match(ecr, /prevent_destroy = true/);
assert.match(ecr, /image_tag_mutability = "IMMUTABLE"/);
assert.match(ecr, /scan_on_push = true/);
assert.match(ecr, /force_delete\s+= false/);
assert.match(ecr, /tagPrefixList = \["git-"\]/);
assert.match(ecr, /countNumber\s+= 30/);
assert.doesNotMatch(ecr, /tagStatus\s+= "untagged"/);
assert.match(imageScan, /trivy_version="0\.72\.0"/);
assert.match(imageScan, /aquasec\/trivy:\$\{trivy_version\}@sha256:[0-9a-f]{64}/);
assert.match(imageScan, /--scanners vuln --pkg-types os,library/);
assert.match(imageScan, /--severity HIGH,CRITICAL --ignore-unfixed/);
assert.match(imageScan, /--exit-code 1 --format table/);
assert.match(imageScan, /--exit-code 1 --format json/);
assert.match(imageSbom, /aquasec\/trivy:0\.72\.0@sha256:[0-9a-f]{64}/);
assert.match(imageSbom, /--format spdx-json/);
assert.match(publisher, /StringEquals/);
assert.doesNotMatch(publisher, /StringLike/);
assert.doesNotMatch(publisher, /ecr:\*/);
assert.doesNotMatch(publisher, /ecr:DescribeImageScanFindings/);
assert.match(publisher, /"ecr:GetAuthorizationToken"\n\s+Resource = "\*"/);
for (const forbidden of [
  "ecr:BatchDeleteImage",
  "ecr:DeleteRepository",
  "ecr:PutLifecyclePolicy",
  "ecr:SetRepositoryPolicy",
  "ecr:TagResource",
  "ecr:UntagResource",
  "s3:",
  "ecs:",
  "ec2:",
  'sts:AssumeRole"',
]) {
  assert(
    !publisher.includes(forbidden),
    `Publisher includes forbidden permission ${forbidden}.`,
  );
}

console.log("Immutable image publication boundary checks passed.");
