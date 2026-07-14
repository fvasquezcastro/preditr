#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-${SCRIPT_DIR}/compose.yaml}"

mkdir -p "${SCRIPT_DIR}/preditr_outputs"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  "${SCRIPT_DIR}/generate_reference_compose.sh" --output "${COMPOSE_FILE}"
fi

cd "${REPO_ROOT}"
docker compose -f "${COMPOSE_FILE}" up
