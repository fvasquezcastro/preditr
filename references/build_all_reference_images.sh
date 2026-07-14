#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Build every enabled PrEditR reference image from references/reference_organisms.tsv.

Usage:
  references/build_all_reference_images.sh [options]

Options:
  --config VALUE   TSV organism config. Default: references/reference_organisms.tsv.
  --push           Push each built image.
  --no-cache       Build each image without cache.
  --dry-run        Print generated Dockerfiles and commands without building.
  -h, --help       Show this help.
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/reference_organisms.tsv"
PUSH="false"
NO_CACHE="false"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG="$2"
      shift 2
      ;;
    --push)
      PUSH="true"
      shift
      ;;
    --no-cache)
      NO_CACHE="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "${CONFIG}" ]]; then
  echo "Config file not found: ${CONFIG}" >&2
  exit 1
fi

line_num=0
while IFS=$'\t' read -r organism label genome_build image bioc_version platform genome_package annotation_package annotation_object annotation_loader annotation_source_loader annotation_transform bioc_packages cran_packages github_packages enabled; do
  line_num=$((line_num + 1))
  if [[ "${line_num}" -eq 1 ]]; then
    continue
  fi
  if [[ -z "${organism}" || "${organism:0:1}" == "#" ]]; then
    continue
  fi
  if [[ "${enabled}" != "true" ]]; then
    continue
  fi

  cmd=(
    "${SCRIPT_DIR}/build_reference_image.sh"
    --organism "${organism}"
    --label "${label}"
    --genome-build "${genome_build}"
    --image "${image}"
    --bioc-version "${bioc_version}"
    --platform "${platform}"
    --genome-package "${genome_package}"
    --annotation-package "${annotation_package}"
    --annotation-object "${annotation_object}"
    --annotation-loader "${annotation_loader}"
    --annotation-source-loader "${annotation_source_loader}"
    --annotation-transform "${annotation_transform}"
  )

  IFS=',' read -r -a bioc_package_array <<< "${bioc_packages}"
  for pkg in "${bioc_package_array[@]}"; do
    if [[ -n "${pkg}" && "${pkg}" != "none" ]]; then
      cmd+=(--package "${pkg}")
    fi
  done

  IFS=',' read -r -a cran_package_array <<< "${cran_packages}"
  for pkg in "${cran_package_array[@]}"; do
    if [[ -n "${pkg}" && "${pkg}" != "none" ]]; then
      cmd+=(--cran-package "${pkg}")
    fi
  done

  IFS=',' read -r -a github_package_array <<< "${github_packages}"
  for pkg in "${github_package_array[@]}"; do
    if [[ -n "${pkg}" && "${pkg}" != "none" ]]; then
      cmd+=(--github-package "${pkg}")
    fi
  done

  if [[ "${PUSH}" == "true" ]]; then
    cmd+=(--push)
  fi
  if [[ "${NO_CACHE}" == "true" ]]; then
    cmd+=(--no-cache)
  fi
  if [[ "${DRY_RUN}" == "true" ]]; then
    cmd+=(--dry-run)
  fi

  echo "Building reference image for ${organism}: ${image}"
  "${cmd[@]}"
done < "${CONFIG}"
