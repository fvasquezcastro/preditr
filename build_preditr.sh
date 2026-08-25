#!/usr/bin/env bash
# Build the PrEditR app image for both architectures in the cloud, one
# arch-suffixed tag each. Each arch layers on its matching base image via the
# BASE_IMAGE build-arg. Pushes directly to Docker Hub.
set -euo pipefail

VERSION=1.10.1

# Ensure the cloud builder exists and is selected (idempotent).
docker buildx create --driver cloud fvasquezcastro/builder8 --use 2>/dev/null || \
  docker buildx use cloud-fvasquezcastro-builder8

for ARCH in amd64 arm64; do
  docker buildx build \
    --no-cache \
    --builder cloud-fvasquezcastro-builder8 \
    --progress=plain \
    --platform "linux/${ARCH}" \
    --build-arg "TARGETPLATFORM=linux/${ARCH}" \
    --build-arg "BASE_IMAGE=fvasquezcastro/preditr_base:v8_${ARCH}" \
    -f preditr.dockerfile \
    -t "fvasquezcastro/preditr:${VERSION}_${ARCH}" \
    --provenance=false \
    --push \
    .
done

# Publish a multi-arch manifest list so plain `fvasquezcastro/preditr:${VERSION}`
# resolves to whichever variant matches the host. Without this, every consumer —
# run/compose.yaml, the Docker Desktop walkthrough, the docs — has to name an
# arch-suffixed tag, which is how Apple Silicon and Windows/ARM users ended up
# running the amd64 build under emulation. The arch-suffixed tags stay published
# for anyone who needs to pin one explicitly.
docker buildx imagetools create \
  -t "fvasquezcastro/preditr:${VERSION}" \
  "fvasquezcastro/preditr:${VERSION}_amd64" \
  "fvasquezcastro/preditr:${VERSION}_arm64"

# Move `latest` onto this release. The README tells readers to download the latest
# published version, so a `latest` that is not re-pointed here would go on serving an
# older build with no signal that it is stale. Copying the version's manifest list
# keeps `latest` multi-arch and byte-identical to the tag it mirrors.
docker buildx imagetools create \
  -t "fvasquezcastro/preditr:latest" \
  "fvasquezcastro/preditr:${VERSION}"

echo "Published fvasquezcastro/preditr:${VERSION} and :latest (multi-arch: amd64 + arm64)"
