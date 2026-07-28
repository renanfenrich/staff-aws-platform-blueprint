#!/usr/bin/env sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
plan_file=$(mktemp "${TMPDIR:-/tmp}/staff-blueprint-bootstrap-plan.XXXXXX")
plan_json=$(mktemp "${TMPDIR:-/tmp}/staff-blueprint-bootstrap-plan-json.XXXXXX")
trap 'rm -f "${plan_file}" "${plan_json}"' EXIT HUP INT TERM

AWS_ACCESS_KEY_ID=credential-free-bootstrap-plan \
AWS_SECRET_ACCESS_KEY=credential-free-bootstrap-plan \
AWS_EC2_METADATA_DISABLED=true \
  terraform -chdir="${repository_root}/infra/bootstrap" plan \
    -input=false \
    -lock=false \
    -refresh=false \
    -out="${plan_file}" \
    -var='cost_center=portfolio' \
    -var='owner=local-validation'

terraform -chdir="${repository_root}/infra/bootstrap" show -json "${plan_file}" >"${plan_json}"

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
