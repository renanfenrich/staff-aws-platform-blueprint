#!/usr/bin/env sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
terraform_dir=$(mktemp -d "${TMPDIR:-/tmp}/staff-blueprint-bootstrap.XXXXXX")
plan_file=$(mktemp "${TMPDIR:-/tmp}/staff-blueprint-bootstrap-plan.XXXXXX")
plan_json=$(mktemp "${TMPDIR:-/tmp}/staff-blueprint-bootstrap-plan-json.XXXXXX")
trap 'rm -rf "${terraform_dir}"; rm -f "${plan_file}" "${plan_json}"' EXIT HUP INT TERM

# The bootstrap root has a partial S3 backend for the approved migration, but
# disabled validation must remain local and credential-free.
find "${repository_root}/infra/bootstrap" \
  -mindepth 1 -maxdepth 1 \
  ! -name .terraform \
  ! -name backend.tf \
  ! -name backend.hcl \
  ! -name '*.tfbackend' \
  ! -name '*.tfstate' \
  ! -name '*.tfstate.*' \
  ! -name '*.tfplan' \
  ! -name terraform.tfvars \
  -exec cp -R {} "${terraform_dir}" \;

terraform -chdir="${terraform_dir}" init -backend=false -input=false

AWS_ACCESS_KEY_ID=credential-free-bootstrap-plan \
AWS_SECRET_ACCESS_KEY=credential-free-bootstrap-plan \
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
    console.error(`Disabled bootstrap plan contains ${changes.length} AWS resource change(s).`);
    process.exit(1);
  }
  console.log("Disabled bootstrap plan contains zero AWS resource changes.");
' <"${plan_json}"
