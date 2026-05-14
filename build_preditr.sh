docker buildx create --driver cloud fvasquezcastro/builder8 --use

docker buildx build \
  --no-cache \
  --builder cloud-fvasquezcastro-builder8 \
  --progress=plain \
  --platform linux/amd64 \
  --build-arg TARGETPLATFORM=linux/amd64 \
  -f preditr.dockerfile \
  -t fvasquezcastro/preditr:v26_amd64 \
  --provenance=false \
  --push \
  .