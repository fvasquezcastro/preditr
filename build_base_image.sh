docker buildx create --driver cloud fvasquezcastro/builder8 --use

docker buildx build \
  --builder cloud-fvasquezcastro-builder8 \
  --platform linux/amd64 \
  --progress=plain \
  -f preditr_base_os.dockerfile \
  -t fvasquezcastro/preditr_base:v7_amd64 \
  --push \
  .