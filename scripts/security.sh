#!/usr/bin/env sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
gitleaks_image="ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f"
trivy_image="aquasec/trivy:0.72.0@sha256:cffe3f5161a47a6823fbd23d985795b3ed72a4c806da4c4df16266c02accdd6f"
scan_image_ref=${SCAN_IMAGE_REF:-staff-aws-platform-blueprint-api:local}
trivy_cache="${TMPDIR:-/tmp}/staff-aws-platform-blueprint-trivy-cache"
mkdir -p "${trivy_cache}"

npm audit --audit-level=high
node "${repository_root}/scripts/validate-aws-foundation.mjs"
node "${repository_root}/scripts/validate-image-publication.mjs"

docker run --rm \
  --volume "${repository_root}:/repo" \
  "${gitleaks_image}" \
  detect --source=/repo --no-git --no-banner --redact

docker run --rm \
  --volume "${trivy_cache}:/root/.cache/trivy" \
  --volume "${repository_root}:/repo" \
  "${trivy_image}" \
  fs --scanners vuln,secret --severity HIGH,CRITICAL --exit-code 1 /repo

docker run --rm \
  --volume "${trivy_cache}:/root/.cache/trivy" \
  --volume "${repository_root}:/repo" \
  "${trivy_image}" \
  config --severity HIGH,CRITICAL --exit-code 1 \
    --ignorefile /repo/.trivyignore.yaml \
    --tf-vars /repo/infra/terraform/tests/security.tfvars \
    /repo/infra/terraform

docker run --rm \
  --volume "${trivy_cache}:/root/.cache/trivy" \
  --volume "${repository_root}:/repo" \
  "${trivy_image}" \
  config --severity HIGH,CRITICAL --exit-code 1 \
    --ignorefile /repo/.trivyignore.yaml \
    --tf-vars /repo/infra/bootstrap/tests/security.tfvars \
    /repo/infra/bootstrap

security_evidence=$(mktemp -d "${TMPDIR:-/tmp}/staff-image-security.XXXXXX")
trap 'rm -rf "${security_evidence}"' EXIT HUP INT TERM
"${repository_root}/scripts/image-scan.sh" \
  "${scan_image_ref}" "${security_evidence}/trivy-results.json"
"${repository_root}/scripts/image-sbom.sh" \
  "${scan_image_ref}" "${security_evidence}/sbom.spdx.json"
