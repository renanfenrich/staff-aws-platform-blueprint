#!/usr/bin/env sh
set -eu

trivy_version="0.72.0"
trivy_image="aquasec/trivy:${trivy_version}@sha256:cffe3f5161a47a6823fbd23d985795b3ed72a4c806da4c4df16266c02accdd6f"

if [ "${1:-}" = "--version" ]; then
  printf '%s\n' "${trivy_version}"
  exit 0
fi

image_ref=${1:-staff-aws-platform-blueprint-api:local}
output_path=${2:-trivy-results.json}
output_directory=$(dirname -- "${output_path}")
mkdir -p "${output_directory}"
output_directory=$(CDPATH= cd -- "${output_directory}" && pwd)
output_name=$(basename -- "${output_path}")
trivy_cache="${TMPDIR:-/tmp}/staff-aws-platform-blueprint-trivy-cache"
mkdir -p "${trivy_cache}"

docker image inspect "${image_ref}" >/dev/null

docker run --rm \
  --volume "${trivy_cache}:/root/.cache/trivy" \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  "${trivy_image}" \
  image --scanners vuln --pkg-types os,library --severity HIGH,CRITICAL --ignore-unfixed \
  --exit-code 1 --format table "${image_ref}"

docker run --rm \
  --volume "${trivy_cache}:/root/.cache/trivy" \
  --volume "${output_directory}:/evidence" \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  "${trivy_image}" \
  image --scanners vuln --pkg-types os,library --severity HIGH,CRITICAL --ignore-unfixed \
  --exit-code 1 --format json --output "/evidence/${output_name}" "${image_ref}"
