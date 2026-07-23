#!/usr/bin/env bash
# Build the base OS image (Bioconductor 3.19 + system libs + R packages) for
# both architectures in the cloud, one arch-suffixed tag each. This matches the
# app image's _amd64/_arm64 tagging convention. Pushes directly to Docker Hub.
#
# NOTE: the CRAN repo is pinned to a jammy x86_64 binary mirror (see
# installResources.R), so the arm64 build compiles packages from source and is
# significantly slower than amd64.
set -euo pipefail

# Ensure the cloud builder exists and is selected (idempotent).
docker buildx create --driver cloud fvasquezcastro/builder8 --use 2>/dev/null || \
  docker buildx use cloud-fvasquezcastro-builder8

for ARCH in amd64 arm64; do
  docker buildx build \
    --builder cloud-fvasquezcastro-builder8 \
    --platform "linux/${ARCH}" \
    --progress=plain \
    -f preditr_base_os.dockerfile \
    -t "fvasquezcastro/preditr_base:v8_${ARCH}" \
    --push \
    .
done
