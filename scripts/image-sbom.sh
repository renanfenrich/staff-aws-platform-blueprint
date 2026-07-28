#!/usr/bin/env sh
set -eu

trivy_image="aquasec/trivy:0.72.0@sha256:cffe3f5161a47a6823fbd23d985795b3ed72a4c806da4c4df16266c02accdd6f"
image_ref=${1:-staff-aws-platform-blueprint-api:local}
output_path=${2:-sbom.spdx.json}
output_directory=$(dirname -- "${output_path}")
mkdir -p "${output_directory}"
output_directory=$(CDPATH= cd -- "${output_directory}" && pwd)
output_name=$(basename -- "${output_path}")
trivy_cache="${TMPDIR:-/tmp}/staff-aws-platform-blueprint-trivy-cache"
mkdir -p "${trivy_cache}"

docker image inspect "${image_ref}" >/dev/null

docker run --rm \
  --volume "${trivy_cache}:/root/.cache/trivy" \
  --volume "${output_directory}:/evidence" \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  "${trivy_image}" \
  image --format spdx-json --output "/evidence/${output_name}" "${image_ref}"
