#!/usr/bin/env bash
# Stage PrEditR reference payloads out of preditr-ref images and into a plain
# directory that both the Shiny app and the CLI consume via PREDITR_REFERENCES_PATH
# / --references_path (or a single organism via --reference).
#
# This is the runtime-agnostic replacement for the Docker-Compose-only init
# containers: it works with Docker AND with Singularity/Apptainer (HPC), because
# the end product is just files on disk — the contract every PrEditR deployment
# shares. Each preditr-ref image carries its payload at /image-refs/<organism>;
# this script copies that into <refs-dir>/<organism>/ (containing
# preditr_reference.json, maps/, rlib/, ...).
#
# Usage:
#   run/sync_references.sh [options] [organism ...]
#
# Examples:
#   run/sync_references.sh --all                      # every enabled organism
#   run/sync_references.sh human mouse                # just these two
#   run/sync_references.sh --runtime singularity yeast
#   run/sync_references.sh --refs-dir /scratch/$USER/preditr_refs --all
#
# Point PrEditR at the result:
#   PREDITR_REFERENCES_PATH=<refs-dir>            (Shiny app / CLI base-dir scan)
#   Rscript PrEditR.R --references_path <refs-dir> --organism human ...
#   Rscript PrEditR.R --reference <refs-dir>/human ...   (single payload)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG="${SCRIPT_DIR}/reference_organisms.tsv"
REFS_DIR="${PREDITR_REFERENCES_PATH:-${SCRIPT_DIR}/preditr_refs}"
RUNTIME="auto"
SYNC_ALL=false

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

REQUESTED=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)   CONFIG="$2"; shift 2 ;;
    --refs-dir) REFS_DIR="$2"; shift 2 ;;
    --runtime)  RUNTIME="$2"; shift 2 ;;
    --all)      SYNC_ALL=true; shift ;;
    -h|--help)  usage; exit 0 ;;
    -*)         echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *)          REQUESTED+=("$1"); shift ;;
  esac
done

if [[ ! -f "${CONFIG}" ]]; then
  echo "Config file not found: ${CONFIG}" >&2
  exit 1
fi

if [[ "${SYNC_ALL}" == "false" && "${#REQUESTED[@]}" -eq 0 ]]; then
  echo "Nothing to do: pass one or more organism ids, or --all." >&2
  usage >&2
  exit 1
fi

# Resolve the container runtime once.
if [[ "${RUNTIME}" == "auto" ]]; then
  if command -v docker >/dev/null 2>&1; then
    RUNTIME="docker"
  elif command -v singularity >/dev/null 2>&1; then
    RUNTIME="singularity"
  elif command -v apptainer >/dev/null 2>&1; then
    RUNTIME="apptainer"
  else
    echo "No container runtime found (docker, singularity, apptainer)." >&2
    exit 1
  fi
fi

mkdir -p "${REFS_DIR}"
REFS_DIR="$(cd "${REFS_DIR}" && pwd)"

# Copy /image-refs/<organism> out of <image> into <REFS_DIR>/<organism>.
stage_docker() {
  local organism="$1" image="$2"
  local cid
  cid="$(docker create "${image}")"
  # shellcheck disable=SC2064
  trap "docker rm -f '${cid}' >/dev/null 2>&1 || true" RETURN
  rm -rf "${REFS_DIR:?}/${organism}"
  docker cp "${cid}:/image-refs/${organism}" "${REFS_DIR}/${organism}"
}

stage_singularity() {
  local organism="$1" image="$2" bin="$3"
  # docker:// lets Singularity/Apptainer consume the same Docker Hub images. The
  # target dir is bind-mounted so the in-container copy lands on the host.
  rm -rf "${REFS_DIR:?}/${organism}"
  "${bin}" exec -B "${REFS_DIR}:${REFS_DIR}" "docker://${image}" \
    sh -c "cp -a /image-refs/${organism} '${REFS_DIR}/${organism}'"
}

stage_one() {
  local organism="$1" image="$2"
  echo "Staging ${organism} from ${image} via ${RUNTIME} -> ${REFS_DIR}/${organism}"
  case "${RUNTIME}" in
    docker)               stage_docker "${organism}" "${image}" ;;
    singularity|apptainer) stage_singularity "${organism}" "${image}" "${RUNTIME}" ;;
    *) echo "Unsupported runtime: ${RUNTIME}" >&2; return 1 ;;
  esac
}

want() {
  local org="$1"
  [[ "${SYNC_ALL}" == "true" ]] && return 0
  local r
  for r in "${REQUESTED[@]}"; do
    [[ "${r}" == "${org}" ]] && return 0
  done
  return 1
}

staged=0
declare -A seen=()
line_num=0
while IFS=$'\t' read -r organism label genome_build image bioc_version platform genome_package annotation_package annotation_object annotation_loader annotation_source_loader annotation_transform bioc_packages cran_packages github_packages standard_chrom_only enabled; do
  line_num=$((line_num + 1))
  [[ "${line_num}" -eq 1 ]] && continue
  [[ -z "${organism}" || "${organism:0:1}" == "#" ]] && continue
  if [[ "${SYNC_ALL}" == "true" && "${enabled}" != "true" ]]; then
    continue
  fi
  want "${organism}" || continue
  seen["${organism}"]=1
  stage_one "${organism}" "${image}"
  staged=$((staged + 1))
done < "${CONFIG}"

# Warn about explicitly requested organisms that were not in the config.
if [[ "${SYNC_ALL}" == "false" ]]; then
  for r in "${REQUESTED[@]}"; do
    if [[ -z "${seen[${r}]:-}" ]]; then
      echo "Warning: organism '${r}' not found in ${CONFIG}; skipped." >&2
    fi
  done
fi

echo "Staged ${staged} organism(s) into ${REFS_DIR}"
