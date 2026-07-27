#!/usr/bin/env sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
plan_file=$(mktemp "${TMPDIR:-/tmp}/staff-blueprint-plan.XXXXXX")
plan_json=$(mktemp "${TMPDIR:-/tmp}/staff-blueprint-plan-json.XXXXXX")
trap 'rm -f "${plan_file}" "${plan_json}"' EXIT HUP INT TERM

# The provider SDK requires a credential-shaped value even when every resource
# is gated off. These local placeholders are non-secret and are never persisted
# or sent to AWS; provider validation and all API lookups are disabled below.
AWS_ACCESS_KEY_ID=credential-free-plan \
AWS_SECRET_ACCESS_KEY=credential-free-plan \
AWS_EC2_METADATA_DISABLED=true \
  terraform -chdir="${repository_root}/infra/terraform" plan \
    -input=false \
    -lock=false \
    -refresh=false \
    -out="${plan_file}" \
    -var='cost_center=portfolio' \
    -var='owner=local-validation'

terraform -chdir="${repository_root}/infra/terraform" show -json "${plan_file}" >"${plan_json}"

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
