#!/usr/bin/env bash
set -eu

fail() {
  echo "preflight failed: $1" >&2
  exit 1
}

: "${BOOTSTRAP_VAR_FILE:?BOOTSTRAP_VAR_FILE is required}"
: "${BOOTSTRAP_BACKEND_CONFIG:?BOOTSTRAP_BACKEND_CONFIG is required}"
: "${EXPECTED_AWS_ACCOUNT_ID:?EXPECTED_AWS_ACCOUNT_ID is required}"
: "${EXPECTED_AWS_REGION:?EXPECTED_AWS_REGION is required}"
: "${APPROVED_BRANCH:?APPROVED_BRANCH is required}"
: "${APPROVED_COMMIT:?APPROVED_COMMIT is required}"

repo_root=$(git rev-parse --show-toplevel)
branch=$(git branch --show-current)
commit=$(git rev-parse HEAD)
[ "$branch" = "$APPROVED_BRANCH" ] || fail "branch does not match the approved branch"
[ "$commit" = "$APPROVED_COMMIT" ] || fail "commit does not match the approved commit"
[ -z "$(git status --porcelain --untracked-files=all)" ] || fail "working tree is not clean"

var_file=$(realpath "$BOOTSTRAP_VAR_FILE") || fail "bootstrap variable file cannot be resolved"
backend_config=$(realpath "$BOOTSTRAP_BACKEND_CONFIG") || fail "backend config cannot be resolved"
[ -f "$var_file" ] || fail "bootstrap variable file does not exist"
[ -f "$backend_config" ] || fail "backend config does not exist"

repo_relative() {
  case "$1" in
    "$repo_root"/*) printf '%s\n' "${1#"$repo_root"/}" ;;
    *) fail "file is outside the repository: $1" ;;
  esac
}

var_relative=$(repo_relative "$var_file")
backend_relative=$(repo_relative "$backend_config")
git check-ignore -q -- "$var_relative" || fail "bootstrap variable file is not ignored by Git"
git check-ignore -q -- "$backend_relative" || fail "backend config is not ignored by Git"

identity=$(aws sts get-caller-identity --output json) || fail "AWS identity lookup failed"
account_id=$(printf '%s' "$identity" | jq -r '.Account')
caller_arn=$(printf '%s' "$identity" | jq -r '.Arn')
[ "$account_id" = "$EXPECTED_AWS_ACCOUNT_ID" ] || fail "AWS account does not match the expected account"

configured_region=${AWS_REGION:-${AWS_DEFAULT_REGION:-}}
if [ -z "$configured_region" ]; then
  configured_region=$(aws configure get region 2>/dev/null || true)
fi
[ "$configured_region" = "$EXPECTED_AWS_REGION" ] || fail "configured AWS region does not match the expected region"

backend_value() {
  awk -F '=' -v name="$1" '
    $1 ~ "^[[:space:]]*" name "[[:space:]]*$" {
      value = $2
      gsub(/[[:space:]]/, "", value)
      gsub(/^"|"$/, "", value)
      found += 1
      result = value
    }
    END { if (found != 1) exit 1; print result }
  ' "$backend_config"
}

grep -Eiq '(^|[[:space:]])(access_key|secret_key|session_token|role_arn)[[:space:]]*=' "$backend_config" &&
  fail "backend config contains credential or role settings"
bucket=$(backend_value bucket) || fail "backend bucket is not a simple configured value"
state_key=$(backend_value key) || fail "backend key is not a simple configured value"
backend_region=$(backend_value region) || fail "backend region is not a simple configured value"
[ "$state_key" = "staff-aws-platform-blueprint/bootstrap/terraform.tfstate" ] ||
  fail "backend key is not the approved bootstrap key"
[ "$backend_region" = "$EXPECTED_AWS_REGION" ] || fail "backend region is not approved"

aws s3api head-bucket --bucket "$bucket" >/dev/null || fail "approved state bucket is unavailable"
bucket_location=$(aws s3api get-bucket-location --bucket "$bucket" --query LocationConstraint --output text)
[ "$bucket_location" = "None" ] && bucket_location=us-east-1
[ "$bucket_location" = "$EXPECTED_AWS_REGION" ] || fail "state bucket region is not approved"
bucket_owner=$(aws s3api get-bucket-acl --bucket "$bucket" --query Owner.ID --output text)
account_owner=$(aws s3api list-buckets --query Owner.ID --output text)
[ -n "$bucket_owner" ] && [ "$bucket_owner" = "$account_owner" ] || fail "state bucket owner does not match the caller account"

versioning=$(aws s3api get-bucket-versioning --bucket "$bucket" --query Status --output text)
[ "$versioning" = "Enabled" ] || fail "state bucket versioning is not enabled"
encryption=$(aws s3api get-bucket-encryption --bucket "$bucket" --output json)
printf '%s' "$encryption" | jq -e '.ServerSideEncryptionConfiguration.Rules | length > 0' >/dev/null ||
  fail "state bucket default encryption is not configured"
public_access=$(aws s3api get-public-access-block --bucket "$bucket" --output json)
printf '%s' "$public_access" | jq -e '
  .PublicAccessBlockConfiguration |
  .BlockPublicAcls == true and .IgnorePublicAcls == true and
  .BlockPublicPolicy == true and .RestrictPublicBuckets == true
' >/dev/null || fail "state bucket public-access block is incomplete"
ownership=$(aws s3api get-bucket-ownership-controls --bucket "$bucket" --output json)
printf '%s' "$ownership" | jq -e '.OwnershipControls.Rules | any(.[]; .ObjectOwnership == "BucketOwnerEnforced")' >/dev/null ||
  fail "state bucket ownership is not BucketOwnerEnforced"
policy=$(aws s3api get-bucket-policy --bucket "$bucket" --query Policy --output text)
printf '%s' "$policy" | jq -e '
  [.Statement[]? | select(.Effect == "Deny") |
    select((.Condition.Bool["aws:SecureTransport"] // "") == "false")] | length > 0
' >/dev/null || fail "state bucket policy does not enforce TLS"

target_exists() {
  objects=$(aws s3api list-objects-v2 --bucket "$bucket" --prefix "$1" --output json) ||
    fail "could not inspect the target key"
  if printf '%s' "$objects" | jq -e --arg key "$1" 'any(.Contents[]?; .Key == $key)' >/dev/null; then
    fail "target object already exists: $1"
  fi
}
target_exists "$state_key"
target_exists "${state_key}.tflock"

state_file="$repo_root/infra/bootstrap/terraform.tfstate"
[ -s "$state_file" ] || fail "local bootstrap state is missing or empty"
lineage=$(jq -er '.lineage' "$state_file") || fail "local state lineage is unavailable"
serial=$(jq -er '.serial' "$state_file") || fail "local state serial is unavailable"
resource_count=$(jq -er '[.resources[]? | (.instances // [null])[]] | length' "$state_file") ||
  fail "local resource-address count is unavailable"

plan_log=$(mktemp "${TMPDIR:-/tmp}/staff-bootstrap-preflight.XXXXXX")
trap 'rm -f "$plan_log"' EXIT HUP INT TERM
if ! terraform -chdir=infra/bootstrap plan \
  -refresh=true -input=false -no-color -detailed-exitcode \
  -var-file="$var_file" >"$plan_log" 2>&1; then
  fail "refresh-enabled bootstrap plan did not return zero changes"
fi

printf 'preflight passed\naccount=%s\ncaller=%s\nregion=%s\nbucket=%s\nkey=%s\nlineage=%s\nserial=%s\nresource_count=%s\nplan=zero-change\n' \
  "$account_id" "${caller_arn##*/}" "$EXPECTED_AWS_REGION" "$bucket" "$state_key" \
  "$lineage" "$serial" "$resource_count"
