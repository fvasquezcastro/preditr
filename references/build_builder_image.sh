#!/usr/bin/env bash
#
# Build (and optionally push) the PrEditR reference-builder image.
#
# The builder is published as the `ref-builder` tag of the existing preditr-ref
# repo (NOT a separate repo): fvasquezcastro/preditr-ref:ref-builder.
#
# Usage:
#   references/build_builder_image.sh                # build locally
#   references/build_builder_image.sh --push         # build and push
#   references/build_builder_image.sh --bioc-version 3.19 --platform linux/amd64
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE="fvasquezcastro/preditr-ref:ref-builder"
BIOC_VERSION="3.19"
PLATFORM="linux/amd64"
DOCKER_CONTEXT_NAME="${DOCKER_CONTEXT_NAME:-default}"
PUSH="false"
NO_CACHE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)         IMAGE="$2"; shift 2 ;;
    --bioc-version)  BIOC_VERSION="$2"; shift 2 ;;
    --platform)      PLATFORM="$2"; shift 2 ;;
    --context)       DOCKER_CONTEXT_NAME="$2"; shift 2 ;;
    --push)          PUSH="true"; shift ;;
    --no-cache)      NO_CACHE="true"; shift ;;
    -h|--help)
      sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

docker_cmd=(docker)
if [[ -n "${DOCKER_CONTEXT_NAME}" ]]; then
  docker_cmd+=(--context "${DOCKER_CONTEXT_NAME}")
fi

build_args=(
  build
  --platform "${PLATFORM}"
  --provenance=false
  --progress plain
  --build-arg "BIOC_VERSION=${BIOC_VERSION}"
  -f "${SCRIPT_DIR}/builder/Dockerfile"
  -t "${IMAGE}"
)
[[ "${NO_CACHE}" == "true" ]] && build_args+=(--no-cache)
[[ "${PUSH}" == "true" ]] && build_args+=(--push)

# Build context is references/ so the Dockerfile can COPY the shared R scripts.
build_args+=("${SCRIPT_DIR}")

echo ">> Building reference-builder image: ${IMAGE} (Bioconductor ${BIOC_VERSION})"
"${docker_cmd[@]}" "${build_args[@]}"
echo ">> Built ${IMAGE}"
