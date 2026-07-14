#!/usr/bin/env bash
# Run PrEditR in CLI mode through Docker Compose, reusing the same reference
# volume the Shiny stack uses. Reference initializer containers run first (via
# depends_on), so organisms you have pulled are synced into /refs before the job.
#
# Usage:
#   run/run_preditr_cli.sh --input /inputs/targets.csv --editors /inputs/editors.csv \
#     --output /outputs --organism human --tmp /outputs/tmp
#
# Put your input CSVs in run/preditr_inputs/ (mounted at /inputs). Results written
# to /outputs appear on the host under run/preditr_outputs/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-${SCRIPT_DIR}/compose.yaml}"

mkdir -p "${SCRIPT_DIR}/preditr_inputs" "${SCRIPT_DIR}/preditr_outputs"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  "${SCRIPT_DIR}/generate_reference_compose.sh" --output "${COMPOSE_FILE}"
fi

cd "${REPO_ROOT}"
# --profile cli activates the preditr-cli service; all args after the service
# name are forwarded to PrEditR.R by the container entrypoint.
docker compose -f "${COMPOSE_FILE}" --profile cli run --rm preditr-cli "$@"
