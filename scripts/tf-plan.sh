#!/usr/bin/env sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
terraform_dir=$(mktemp -d "${TMPDIR:-/tmp}/staff-blueprint-terraform.XXXXXX")
plan_file=$(mktemp "${TMPDIR:-/tmp}/staff-blueprint-plan.XXXXXX")
plan_json=$(mktemp "${TMPDIR:-/tmp}/staff-blueprint-plan-json.XXXXXX")
trap 'rm -rf "${terraform_dir}"; rm -f "${plan_file}" "${plan_json}"' EXIT HUP INT TERM

# Terraform validates and tests a partial backend with -backend=false, but it
# will not plan that root until the S3 backend is configured. Plan an otherwise
# identical temporary copy without backend.tf to preserve the offline gate.
find "${repository_root}/infra/terraform" \
  -mindepth 1 -maxdepth 1 \
  ! -name .terraform \
  ! -name backend.tf \
  -exec cp -R {} "${terraform_dir}" \;

terraform -chdir="${terraform_dir}" init -backend=false -input=false

# The provider SDK requires a credential-shaped value even when every resource
# is gated off. These local placeholders are non-secret and are never persisted
# or sent to AWS; provider validation and all API lookups are disabled below.
AWS_ACCESS_KEY_ID=credential-free-plan \
AWS_SECRET_ACCESS_KEY=credential-free-plan \
AWS_EC2_METADATA_DISABLED=true \
  terraform -chdir="${terraform_dir}" plan \
    -input=false \
    -lock=false \
    -refresh=false \
    -out="${plan_file}" \
    -var='cost_center=portfolio' \
    -var='owner=local-validation'

terraform -chdir="${terraform_dir}" show -json "${plan_file}" >"${plan_json}"

node -e '
  const fs = require("node:fs");
  const plan = JSON.parse(fs.readFileSync(0, "utf8"));
  const changes = (plan.resource_changes ?? []).filter(
    ({ change }) => change.actions.some((action) => action !== "no-op"),
  );
  if (changes.length > 0) {
    console.error(`Disabled plan contains ${changes.length} AWS resource change(s).`);
    process.exit(1);
  }
  console.log("Disabled plan contains zero AWS resource changes.");
' <"${plan_json}"
