#!/bin/sh
# PrEditR container entrypoint.
#   no arguments  -> launch the Shiny web app (Docker Compose / Docker Desktop)
#   any arguments -> run the CLI: `docker run <image> --input ... --organism ...`
# One image serves both modes so the reference-image / /refs contract is shared.
set -e

if [ "$#" -eq 0 ]; then
  exec R -e "shiny::runApp('/app', host='0.0.0.0', port=3838)"
else
  exec env PREDITR_MODE=CLI Rscript /app/PrEditR.R "$@"
fi
