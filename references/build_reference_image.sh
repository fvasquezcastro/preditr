#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Build one PrEditR organism reference image from Bioconductor packages.

Usage:
  references/build_reference_image.sh \
    --organism human \
    --label "Human" \
    --genome-build GRCh38 \
    --image fvasquezcastro/preditr-ref:human-grch38 \
    --genome-package BSgenome.Hsapiens.UCSC.hg38 \
    --annotation-package TxDb.Hsapiens.UCSC.hg38.knownGene \
    --annotation-object TxDb.Hsapiens.UCSC.hg38.knownGene \
    --annotation-loader rds \
    --annotation-source-loader package-object \
    --annotation-transform txdb2grangeslist \
    --package BSgenome.Hsapiens.UCSC.hg38 \
    --package TxDb.Hsapiens.UCSC.hg38.knownGene

Options:
  --organism VALUE             Stable organism id, for example human or mouse.
  --label VALUE                User-facing organism label.
  --genome-build VALUE         Genome build label, for example GRCh38 or mm10.
  --image VALUE                Docker image tag to build.
  --bioc-version VALUE         Bioconductor Docker version. Default: 3.19.
  --platform VALUE             Docker platform. Default: linux/amd64.
  --genome-package VALUE       R package containing the BSgenome object.
  --annotation-package VALUE   R package containing the source annotation object.
  --annotation-object VALUE    Source annotation object name.
  --annotation-loader VALUE    Runtime loader: data, package-object, or rds. Default: data.
  --annotation-source-loader VALUE
                               Source loader for rds builds: data or package-object. Default: package-object.
  --annotation-transform VALUE Transform for rds builds: none or txdb2grangeslist. Default: none.
  --annotation-rds-path VALUE  Runtime RDS path under the reference directory. Default: annotation/txdb.rds.
  --package VALUE              Bioconductor package to install. Repeatable.
  --cran-package VALUE         CRAN package to install. Repeatable.
  --github-package VALUE       GitHub package (owner/repo) installed at build time,
                               e.g. crisprVerse/crisprDesignData. Repeatable.
  --context VALUE              Docker context name. Default: default.
  --push                       Push the built image.
  --no-cache                   Build without cache.
  --dry-run                    Print generated Dockerfile and docker command only.
  -h, --help                   Show this help.

The generated image stores the reference payload at:
  /image-refs/<organism>/

At runtime, use the image as a one-shot Compose service that copies that
directory into a shared /refs Docker volume.
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ORGANISM=""
LABEL=""
GENOME_BUILD=""
IMAGE=""
BIOC_VERSION="3.19"
PLATFORM="linux/amd64"
GENOME_PACKAGE=""
ANNOTATION_PACKAGE=""
ANNOTATION_OBJECT=""
ANNOTATION_LOADER="data"
ANNOTATION_SOURCE_LOADER="package-object"
ANNOTATION_TRANSFORM="none"
ANNOTATION_RDS_PATH="annotation/txdb.rds"
DOCKER_CONTEXT_NAME="${DOCKER_CONTEXT_NAME:-default}"
PUSH="false"
NO_CACHE="false"
DRY_RUN="false"
PACKAGES=()
CRAN_PACKAGES=()
GITHUB_PACKAGES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --organism)
      ORGANISM="$2"
      shift 2
      ;;
    --label)
      LABEL="$2"
      shift 2
      ;;
    --genome-build)
      GENOME_BUILD="$2"
      shift 2
      ;;
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --bioc-version)
      BIOC_VERSION="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --genome-package)
      GENOME_PACKAGE="$2"
      shift 2
      ;;
    --annotation-package)
      ANNOTATION_PACKAGE="$2"
      shift 2
      ;;
    --annotation-object)
      ANNOTATION_OBJECT="$2"
      shift 2
      ;;
    --annotation-loader)
      ANNOTATION_LOADER="$2"
      shift 2
      ;;
    --annotation-source-loader)
      ANNOTATION_SOURCE_LOADER="$2"
      shift 2
      ;;
    --annotation-transform)
      ANNOTATION_TRANSFORM="$2"
      shift 2
      ;;
    --annotation-rds-path)
      ANNOTATION_RDS_PATH="$2"
      shift 2
      ;;
    --package)
      PACKAGES+=("$2")
      shift 2
      ;;
    --cran-package)
      CRAN_PACKAGES+=("$2")
      shift 2
      ;;
    --github-package)
      GITHUB_PACKAGES+=("$2")
      shift 2
      ;;
    --context)
      DOCKER_CONTEXT_NAME="$2"
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

required_vars=(
  ORGANISM
  LABEL
  GENOME_BUILD
  IMAGE
  GENOME_PACKAGE
  ANNOTATION_PACKAGE
  ANNOTATION_OBJECT
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name}" ]]; then
    echo "Missing required option for ${var_name}" >&2
    usage >&2
    exit 1
  fi
done

if [[ "${#PACKAGES[@]}" -eq 0 ]]; then
  echo "At least one --package is required." >&2
  exit 1
fi

if [[ "${ANNOTATION_LOADER}" != "data" && "${ANNOTATION_LOADER}" != "package-object" && "${ANNOTATION_LOADER}" != "rds" ]]; then
  echo "--annotation-loader must be data, package-object, or rds." >&2
  exit 1
fi

if [[ "${ANNOTATION_SOURCE_LOADER}" != "data" && "${ANNOTATION_SOURCE_LOADER}" != "package-object" ]]; then
  echo "--annotation-source-loader must be either data or package-object." >&2
  exit 1
fi

if [[ "${ANNOTATION_TRANSFORM}" != "none" && "${ANNOTATION_TRANSFORM}" != "txdb2grangeslist" ]]; then
  echo "--annotation-transform must be either none or txdb2grangeslist." >&2
  exit 1
fi

CRAN_PACKAGES=("jsonlite" "${CRAN_PACKAGES[@]}")
if [[ "${ANNOTATION_TRANSFORM}" == "txdb2grangeslist" ]]; then
  PACKAGES=("crisprDesign" "${PACKAGES[@]}")
fi

package_r_vector() {
  local values=("$@")
  local first="true"
  for value in "${values[@]}"; do
    if [[ "${first}" == "false" ]]; then
      printf ', '
    fi
    first="false"
    printf '"%s"' "${value//\"/\\\"}"
  done
}

BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/preditr-ref-build.XXXXXX")"
cleanup() {
  rm -rf "${BUILD_DIR}"
}
trap cleanup EXIT

DOCKERFILE="${BUILD_DIR}/Dockerfile"
PACKAGES_R="$(package_r_vector "${PACKAGES[@]}")"
CRAN_PACKAGES_R="$(package_r_vector "${CRAN_PACKAGES[@]}")"
if [[ "${#GITHUB_PACKAGES[@]}" -gt 0 ]]; then
  GITHUB_PACKAGES_R="$(package_r_vector "${GITHUB_PACKAGES[@]}")"
else
  GITHUB_PACKAGES_R=""
fi

cp "${SCRIPT_DIR}/check_reference_compatibility.R" "${BUILD_DIR}/check_reference_compatibility.R"
mkdir -p "${BUILD_DIR}/maps"
if [[ -d "${REPO_ROOT}/maps/${ORGANISM}" ]]; then
  cp -a "${REPO_ROOT}/maps/${ORGANISM}" "${BUILD_DIR}/maps/${ORGANISM}"
fi

cat > "${DOCKERFILE}" <<DOCKERFILE
# ---- Stage 1: builder (full R/Bioconductor) — produces /image-refs/<organism> ----
FROM bioconductor/bioconductor_docker:${BIOC_VERSION} AS builder

ARG ORGANISM=${ORGANISM}
ARG ORGANISM_LABEL="${LABEL}"
ARG GENOME_BUILD="${GENOME_BUILD}"
ARG GENOME_PACKAGE="${GENOME_PACKAGE}"
ARG ANNOTATION_PACKAGE="${ANNOTATION_PACKAGE}"
ARG ANNOTATION_OBJECT="${ANNOTATION_OBJECT}"
ARG ANNOTATION_LOADER="${ANNOTATION_LOADER}"
ARG ANNOTATION_SOURCE_LOADER="${ANNOTATION_SOURCE_LOADER}"
ARG ANNOTATION_TRANSFORM="${ANNOTATION_TRANSFORM}"
ARG ANNOTATION_RDS_PATH="${ANNOTATION_RDS_PATH}"

ENV ORGANISM=\${ORGANISM}
ENV ORGANISM_LABEL=\${ORGANISM_LABEL}
ENV GENOME_BUILD=\${GENOME_BUILD}
ENV GENOME_PACKAGE=\${GENOME_PACKAGE}
ENV ANNOTATION_PACKAGE=\${ANNOTATION_PACKAGE}
ENV ANNOTATION_OBJECT=\${ANNOTATION_OBJECT}
ENV ANNOTATION_LOADER=\${ANNOTATION_LOADER}
ENV ANNOTATION_SOURCE_LOADER=\${ANNOTATION_SOURCE_LOADER}
ENV ANNOTATION_TRANSFORM=\${ANNOTATION_TRANSFORM}
ENV ANNOTATION_RDS_PATH=\${ANNOTATION_RDS_PATH}
ENV PREDITR_REFERENCE_DIR=/image-refs/\${ORGANISM}
ENV PREDITR_REFERENCE_RLIB=/image-refs/\${ORGANISM}/rlib

RUN mkdir -p "\${PREDITR_REFERENCE_RLIB}" "\${PREDITR_REFERENCE_DIR}" "\${PREDITR_REFERENCE_DIR}/annotation"

RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager"); BiocManager::install(version = "${BIOC_VERSION}", ask = FALSE, update = FALSE)'

RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); cran_packages <- c(${CRAN_PACKAGES_R}); if (length(cran_packages) > 0) install.packages(cran_packages, lib = Sys.getenv("PREDITR_REFERENCE_RLIB"))'

RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); .libPaths(c(Sys.getenv("PREDITR_REFERENCE_RLIB"), .libPaths())); packages <- c(${PACKAGES_R}); BiocManager::install(packages, lib = Sys.getenv("PREDITR_REFERENCE_RLIB"), ask = FALSE, update = FALSE)'

# GitHub packages (e.g. crisprDesignData) are only needed at build time to
# produce annotation/txdb.rds, so they install into the default library rather
# than the shipped rlib.
RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); gh <- c(${GITHUB_PACKAGES_R}); if (length(gh) > 0) { if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes"); remotes::install_github(gh, upgrade = "never") }'

RUN Rscript -e '.libPaths(c(Sys.getenv("PREDITR_REFERENCE_RLIB"), .libPaths())); if (identical(Sys.getenv("ANNOTATION_LOADER"), "rds")) { load_source <- function() { if (identical(Sys.getenv("ANNOTATION_SOURCE_LOADER"), "data")) { env <- new.env(parent = emptyenv()); utils::data(list = Sys.getenv("ANNOTATION_OBJECT"), package = Sys.getenv("ANNOTATION_PACKAGE"), envir = env); env[[Sys.getenv("ANNOTATION_OBJECT")]] } else { getExportedValue(Sys.getenv("ANNOTATION_PACKAGE"), Sys.getenv("ANNOTATION_OBJECT")) } }; txdb <- load_source(); if (identical(Sys.getenv("ANNOTATION_TRANSFORM"), "txdb2grangeslist")) { txdb <- crisprDesign::TxDb2GRangesList(txdb) }; rds_path <- file.path(Sys.getenv("PREDITR_REFERENCE_DIR"), Sys.getenv("ANNOTATION_RDS_PATH")); dir.create(dirname(rds_path), recursive = TRUE, showWarnings = FALSE); saveRDS(txdb, rds_path) }'

RUN Rscript -e 'ref_dir <- Sys.getenv("PREDITR_REFERENCE_DIR"); manifest <- file.path(ref_dir, "preditr_reference.json"); packages <- c(${PACKAGES_R}); annotation_path_line <- if (identical(Sys.getenv("ANNOTATION_LOADER"), "rds")) paste0("  \\"annotation_path\\": \\"", Sys.getenv("ANNOTATION_RDS_PATH"), "\\"", ",") else NULL; lines <- c("{", "  \\"schema_version\\": \\"0.1\\",", paste0("  \\"organism_id\\": \\"", Sys.getenv("ORGANISM"), "\\"", ","), paste0("  \\"organism_label\\": \\"", Sys.getenv("ORGANISM_LABEL"), "\\"", ","), paste0("  \\"genome_build\\": \\"", Sys.getenv("GENOME_BUILD"), "\\"", ","), "  \\"reference_kind\\": \\"bioconductor_packages\\",", "  \\"bioconductor_version\\": \\"${BIOC_VERSION}\\",", "  \\"r_library_path\\": \\"rlib\\",", paste0("  \\"genome_package\\": \\"", Sys.getenv("GENOME_PACKAGE"), "\\"", ","), paste0("  \\"annotation_package\\": \\"", Sys.getenv("ANNOTATION_PACKAGE"), "\\"", ","), paste0("  \\"annotation_object\\": \\"", Sys.getenv("ANNOTATION_OBJECT"), "\\"", ","), paste0("  \\"annotation_loader\\": \\"", Sys.getenv("ANNOTATION_LOADER"), "\\"", ","), paste0("  \\"annotation_source_loader\\": \\"", Sys.getenv("ANNOTATION_SOURCE_LOADER"), "\\"", ","), paste0("  \\"annotation_transform\\": \\"", Sys.getenv("ANNOTATION_TRANSFORM"), "\\"", ","), annotation_path_line, "  \\"packages\\": [", paste0("    ", paste(sprintf("\\"%s\\"", packages), collapse = ",\\n    ")), "  ]", "}"); writeLines(lines, manifest)'

RUN Rscript -e '.libPaths(c(Sys.getenv("PREDITR_REFERENCE_RLIB"), .libPaths())); pkgs <- installed.packages(lib.loc = Sys.getenv("PREDITR_REFERENCE_RLIB")); utils::write.table(as.data.frame(pkgs[, c("Package", "Version", "LibPath")]), file = file.path(Sys.getenv("PREDITR_REFERENCE_DIR"), "installed_packages.tsv"), sep = "\\t", quote = FALSE, row.names = FALSE)'

RUN Rscript -e 'loader <- c("load_preditr_reference_payload <- function(reference_dir) {", "  manifest <- jsonlite::fromJSON(file.path(reference_dir, \\"preditr_reference.json\\"))", "  .libPaths(c(file.path(reference_dir, manifest\$r_library_path), .libPaths()))", "  requireNamespace(manifest\$genome_package, quietly = FALSE)", "  requireNamespace(manifest\$annotation_package, quietly = FALSE)", "  if (identical(manifest\$annotation_loader, \\"data\\")) {", "    env <- new.env(parent = emptyenv())", "    utils::data(list = manifest\$annotation_object, package = manifest\$annotation_package, envir = env)", "    txdb <- env[[manifest\$annotation_object]]", "  } else if (identical(manifest\$annotation_loader, \\"package-object\\")) {", "    txdb <- getExportedValue(manifest\$annotation_package, manifest\$annotation_object)", "  } else if (identical(manifest\$annotation_loader, \\"rds\\")) {", "    txdb <- readRDS(file.path(reference_dir, manifest\$annotation_path))", "  } else {", "    stop(\\"Unsupported annotation_loader: \\", manifest\$annotation_loader)", "  }", "  list(manifest = manifest, txdb = txdb, genome_package = manifest\$genome_package)", "}"); writeLines(loader, file.path(Sys.getenv("PREDITR_REFERENCE_DIR"), "reference_loader.R"))'

COPY check_reference_compatibility.R /tmp/check_reference_compatibility.R
COPY maps /tmp/preditr-maps

RUN if [ -d "/tmp/preditr-maps/\${ORGANISM}" ]; then cp -a "/tmp/preditr-maps/\${ORGANISM}" "\${PREDITR_REFERENCE_DIR}/maps"; fi

RUN Rscript /tmp/check_reference_compatibility.R "\${PREDITR_REFERENCE_DIR}" /tmp/preditr-maps

# Strip help/docs/vignettes/tests from the shipped rlib — not needed at runtime.
# Keeps DESCRIPTION/NAMESPACE/R/libs/data/extdata (the 2bit genome is in extdata).
RUN find "\${PREDITR_REFERENCE_RLIB}" -type d \( -name help -o -name html -o -name doc -o -name examples -o -name tests -o -name unitTests \) -exec rm -rf {} + 2>/dev/null || true

# ---- Stage 2: minimal carrier (no R) — only the payload + a shell to copy it ----
FROM debian:stable-slim
COPY --from=builder /image-refs/${ORGANISM} /image-refs/${ORGANISM}
CMD ["sh", "-c", "rm -rf /refs/${ORGANISM} && mkdir -p /refs && cp -a /image-refs/${ORGANISM} /refs/${ORGANISM}"]
DOCKERFILE

docker_cmd=(docker)
if [[ -n "${DOCKER_CONTEXT_NAME}" ]]; then
  docker_cmd+=(--context "${DOCKER_CONTEXT_NAME}")
fi

build_args=(
  build
  --platform "${PLATFORM}"
  --provenance=false
  --progress plain
  -f "${DOCKERFILE}"
  -t "${IMAGE}"
)

if [[ "${NO_CACHE}" == "true" ]]; then
  build_args+=(--no-cache)
fi

if [[ "${PUSH}" == "true" ]]; then
  build_args+=(--push)
fi

build_args+=("${BUILD_DIR}")

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "Generated Dockerfile:"
  echo "---------------------"
  sed -n '1,240p' "${DOCKERFILE}"
  echo
  echo "Docker command:"
  printf '%q ' "${docker_cmd[@]}" "${build_args[@]}"
  echo
  exit 0
fi

"${docker_cmd[@]}" "${build_args[@]}"

echo "Built reference image: ${IMAGE}"
