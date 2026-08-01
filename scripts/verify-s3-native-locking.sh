#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "locking verification failed: $1" >&2
  exit 1
}

root_name=${1:-}
: "${BACKEND_CONFIG:?BACKEND_CONFIG is required}"
: "${EXPECTED_STATE_KEY:?EXPECTED_STATE_KEY is required}"
timeout_seconds=${TIMEOUT_SECONDS:-120}

repo_root=$(git rev-parse --show-toplevel)
[ -z "$(git status --porcelain --untracked-files=all)" ] || fail "working tree is not clean"
backend_config=$(realpath "$BACKEND_CONFIG")
[ -f "$backend_config" ] || fail "backend config does not exist"
case "$backend_config" in "$repo_root"/*) ;; *) fail "backend config is outside the repository" ;; esac

case "$root_name" in
  bootstrap)
    root_dir="$repo_root/infra/bootstrap"
    expected_key="staff-aws-platform-blueprint/bootstrap/terraform.tfstate"
    ;;
  runtime)
    root_dir="$repo_root/infra/terraform"
    expected_key="staff-aws-platform-blueprint/sandbox/terraform.tfstate"
    ;;
  *) fail "root must be bootstrap or runtime" ;;
esac
[ "$EXPECTED_STATE_KEY" = "$expected_key" ] || fail "expected state key does not match the selected root"

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

bucket=$(backend_value bucket) || fail "backend bucket is not a simple value"
configured_key=$(backend_value key) || fail "backend key is not a simple value"
[ "$configured_key" = "$EXPECTED_STATE_KEY" ] || fail "backend config key does not match the expected key"
aws s3api head-bucket --bucket "$bucket" >/dev/null || fail "state bucket is unavailable"

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/staff-s3-lock-test.XXXXXX")
first_pid=
cleanup() {
  if [ -n "${first_pid:-}" ] && kill -0 "$first_pid" 2>/dev/null; then
    kill -SIGCONT "$first_pid" 2>/dev/null || true
    kill -INT "$first_pid" 2>/dev/null || true
    wait "$first_pid" 2>/dev/null || true
  fi
  rm -rf "$temp_dir"
}
trap cleanup EXIT HUP INT TERM

terraform -chdir="$root_dir" init -input=false -reconfigure \
  -backend-config="$backend_config" >"$temp_dir/init.log" 2>&1 || fail "remote initialization failed"

terraform -chdir="$root_dir" plan -refresh=true -input=false -no-color \
  -lock=true -lock-timeout=0s >"$temp_dir/first-plan.log" 2>&1 &
first_pid=$!

lock_key="${EXPECTED_STATE_KEY}.tflock"
deadline=$((SECONDS + timeout_seconds))
lock_size=
while [ "$SECONDS" -lt "$deadline" ]; do
  if lock_size=$(aws s3api head-object --bucket "$bucket" --key "$lock_key" \
    --query ContentLength --output text 2>/dev/null); then
    [ "${lock_size:-0}" -gt 0 ] || fail "Terraform lock object is empty"
    break
  fi
  if ! kill -0 "$first_pid" 2>/dev/null; then
    fail "first plan completed before lock contention could be established"
  fi
  sleep 1
done
[ -n "${lock_size:-}" ] || fail "timed out waiting for Terraform to create the lock"
kill -SIGSTOP "$first_pid" || fail "could not pause the lock-owning Terraform process"

if timeout --signal=TERM "$timeout_seconds" terraform -chdir="$root_dir" plan \
  -refresh=true -input=false -no-color -lock=true -lock-timeout=0s \
  >"$temp_dir/second-plan.log" 2>&1; then
  second_status=0
else
  second_status=$?
fi
[ "$second_status" -ne 0 ] || fail "second plan unexpectedly acquired the state lock"
grep -Eiq 'state lock|Error acquiring' "$temp_dir/second-plan.log" ||
  fail "second plan failed without a state-lock acquisition error"

kill -SIGCONT "$first_pid" || fail "could not resume the first Terraform process"
kill -INT "$first_pid" 2>/dev/null || true
if wait "$first_pid"; then
  first_status=0
else
  first_status=$?
fi
first_pid=
[ "$first_status" -ne 124 ] || fail "first plan timed out"

deadline=$((SECONDS + timeout_seconds))
while [ "$SECONDS" -lt "$deadline" ]; do
  if ! aws s3api head-object --bucket "$bucket" --key "$lock_key" >/dev/null 2>&1; then
    printf 'native S3 locking verified: root=%s key=%s second_plan=lock_rejected lock_cleanup=natural\n' \
      "$root_name" "$EXPECTED_STATE_KEY"
    exit 0
  fi
  sleep 1
done
fail "Terraform did not remove the lock object naturally"
