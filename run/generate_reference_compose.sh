#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Generate a Docker Compose file for the configured PrEditR reference images.

Usage:
  run/generate_reference_compose.sh [options]

Options:
  --config VALUE        TSV organism config. Default: run/reference_organisms.tsv.
  --output VALUE        Compose output file. Default: run/compose.yaml.
  --app-image VALUE     Shiny app image. Default: fvasquezcastro/preditr:1.9.0_amd64.
  --port VALUE          Host port for Shiny. Default: 3838.
  --project-name VALUE  Compose project name. Default: preditr.
  --no-filter           Wire every enabled organism even if its reference image is
                        not present locally (compose up will pull it). By default,
                        only enabled organisms whose image is already present in the
                        active Docker context are wired.
  -h, --help            Show this help.

Only rows with enabled=true are considered. By default the generator additionally
keeps only those whose preditr-ref image is already present locally (docker image
ls), so the stack reflects what has actually been pulled onto this machine.
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The organism registry lives with the reference-building repo (preditr_ref); a copy
# is kept here as run/reference_organisms.tsv so this generator stays self-contained.
CONFIG="${SCRIPT_DIR}/reference_organisms.tsv"
OUTPUT="${SCRIPT_DIR}/compose.yaml"
APP_IMAGE="${PREDITR_APP_IMAGE:-fvasquezcastro/preditr:1.9.0_amd64}"
PORT="${PREDITR_SHINY_PORT:-3838}"
PROJECT_NAME="preditr"
FILTER_LOCAL=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --app-image)
      APP_IMAGE="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --project-name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --no-filter)
      FILTER_LOCAL=false
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

# Decide whether we can (and should) filter enabled organisms down to those whose
# reference image is already present in the active Docker context. This is how the
# generated stack "looks into the docker images on the machine": organisms whose
# image has not been pulled are skipped rather than triggering a pull on `up`.
# If the docker CLI is unavailable we cannot introspect, so we degrade to wiring
# all enabled organisms (equivalent to --no-filter) and say so.
if [[ "${FILTER_LOCAL}" == "true" ]] && ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI not found; cannot filter by locally present images. Wiring all enabled organisms." >&2
  FILTER_LOCAL=false
fi

# Return 0 if the given image reference exists in the active Docker context.
image_present() {
  [[ -n "$(docker image ls -q "$1" 2>/dev/null)" ]]
}

mkdir -p "$(dirname "${OUTPUT}")"

tmp_output="$(mktemp "${TMPDIR:-/tmp}/preditr-compose.XXXXXX")"
cleanup() {
  rm -f "${tmp_output}"
}
trap cleanup EXIT

cat > "${tmp_output}" <<YAML
name: ${PROJECT_NAME}

services:
YAML

enabled_services=()
skipped_missing=()
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

  # Skip enabled organisms whose reference image has not been pulled locally.
  if [[ "${FILTER_LOCAL}" == "true" ]] && ! image_present "${image}"; then
    skipped_missing+=("${organism} (${image})")
    continue
  fi

  service_name="refs-${organism}"
  enabled_services+=("${service_name}")

  cat >> "${tmp_output}" <<YAML
  ${service_name}:
    image: ${image}
    platform: ${platform}
    volumes:
      - preditr_refs:/refs
    command: ["sh", "-c", "rm -rf /refs/${organism} && mkdir -p /refs && cp -a /image-refs/${organism} /refs/${organism}"]
    restart: "no"

YAML
done < "${CONFIG}"

cat >> "${tmp_output}" <<YAML
  preditr-shiny:
    image: ${APP_IMAGE}
    ports:
      - "${PORT}:3838"
    volumes:
      - preditr_refs:/refs
      - ./preditr_outputs:/outputs
    environment:
      PREDITR_HOSTED: "TRUE"
      PREDITR_REFERENCES_PATH: /refs
      PREDITR_OUTPUTS_PATH: /outputs
      PREDITR_THREADS: "\${PREDITR_THREADS:-2}"
      PREDITR_INPUT_ROWS: "\${PREDITR_INPUT_ROWS:-500}"
      PREDITR_FILE_SIZE: "\${PREDITR_FILE_SIZE:-500}"
YAML

if [[ "${#enabled_services[@]}" -gt 0 ]]; then
  cat >> "${tmp_output}" <<'YAML'
    depends_on:
YAML
  for service_name in "${enabled_services[@]}"; do
    cat >> "${tmp_output}" <<YAML
      ${service_name}:
        condition: service_completed_successfully
YAML
  done
fi

# CLI service (opt-in via the "cli" profile so it does not start on `up`):
#   docker compose -f run/compose.yaml run --rm preditr-cli \
#     --input /inputs/targets.csv --editors /inputs/editors.csv \
#     --output /outputs --organism human --tmp /outputs/tmp
cat >> "${tmp_output}" <<YAML

  preditr-cli:
    image: ${APP_IMAGE}
    profiles: ["cli"]
    volumes:
      - preditr_refs:/refs
      - ./preditr_inputs:/inputs
      - ./preditr_outputs:/outputs
    environment:
      PREDITR_REFERENCES_PATH: /refs
YAML

if [[ "${#enabled_services[@]}" -gt 0 ]]; then
  cat >> "${tmp_output}" <<'YAML'
    depends_on:
YAML
  for service_name in "${enabled_services[@]}"; do
    cat >> "${tmp_output}" <<YAML
      ${service_name}:
        condition: service_completed_successfully
YAML
  done
fi

cat >> "${tmp_output}" <<'YAML'

volumes:
  preditr_refs:
YAML

mv "${tmp_output}" "${OUTPUT}"
trap - EXIT

echo "Generated Compose file: ${OUTPUT}"
echo "Wired reference services: ${#enabled_services[@]}"
if [[ "${#skipped_missing[@]}" -gt 0 ]]; then
  echo "Skipped ${#skipped_missing[@]} enabled organism(s) whose image is not present locally:" >&2
  for entry in "${skipped_missing[@]}"; do
    echo "  - ${entry}" >&2
  done
  echo "Pull the image(s) and re-run, or pass --no-filter to wire them anyway." >&2
fi
