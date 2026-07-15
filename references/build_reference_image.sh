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
  --reference-kind VALUE       bioconductor_packages (default) or fasta_gff.
                               fasta_gff builds the reference from a user genome
                               FASTA + annotation GFF3/GTF instead of Bioconductor
                               genome/annotation packages.

fasta_gff options (required in --reference-kind fasta_gff):
  --genome-fasta VALUE         Path to the genome FASTA (.fa/.fa.gz). Forged into a
                               BSgenome package with BSgenomeForge and shipped in rlib/.
  --annotation-gff VALUE       Path to the annotation GFF3/GTF (.gff3/.gtf[.gz]).
  --annotation-format VALUE    gff3 | gtf | auto. Default auto (inferred from extension).
  --uniprot-map VALUE          Optional UniProt<->transcript TSV enabling UniProt-ID
                               input. Columns: transcript_id, uniprot_id[, is_canonical,
                               isoform_of]. When omitted, the reference builds without
                               maps (UniProt-ID input disabled) and --allow-missing-maps
                               is implied.
  --genome-organism VALUE      Binomial ("Genus species") used only to name the forged
                               BSgenome package. Default: --label.
  --provider VALUE             Provider token in the forged package name. Default: custom.

bioconductor_packages options:
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
  --allow-non-builtin          Permit organism ids other than human/mouse
                               (sets PREDITR_ALLOW_NON_BUILTIN_REFERENCE=TRUE in the build).
  --allow-missing-maps         Build the reference payload even when maps/<organism>
                               is absent (sets PREDITR_ALLOW_MISSING_MAPS=TRUE). The genome
                               and annotation are still validated; add maps and rebuild later.
  --standard-chrom-only VALUE  true|false. For txdb2grangeslist builds, controls the
                               standardChromOnly argument to crisprDesign::TxDb2GRangesList.
                               Default true. Set false for organisms whose species lacks a
                               GenomeInfoDb UCSC seqlevels-style entry (e.g. zebrafish,
                               chicken), which otherwise fail in keepStandardChromosomes().
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
REFERENCE_KIND="bioconductor_packages"
GENOME_FASTA=""
ANNOTATION_GFF=""
ANNOTATION_FORMAT="auto"
UNIPROT_MAP=""
GENOME_ORGANISM=""
GENOME_PROVIDER="custom"
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
ALLOW_NON_BUILTIN="false"
ALLOW_MISSING_MAPS="false"
STANDARD_CHROM_ONLY="true"
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
    --reference-kind)
      REFERENCE_KIND="$2"
      shift 2
      ;;
    --genome-fasta)
      GENOME_FASTA="$2"
      shift 2
      ;;
    --annotation-gff)
      ANNOTATION_GFF="$2"
      shift 2
      ;;
    --annotation-format)
      ANNOTATION_FORMAT="$2"
      shift 2
      ;;
    --uniprot-map)
      UNIPROT_MAP="$2"
      shift 2
      ;;
    --genome-organism)
      GENOME_ORGANISM="$2"
      shift 2
      ;;
    --provider)
      GENOME_PROVIDER="$2"
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
    --allow-non-builtin)
      ALLOW_NON_BUILTIN="true"
      shift
      ;;
    --allow-missing-maps)
      ALLOW_MISSING_MAPS="true"
      shift
      ;;
    --standard-chrom-only)
      STANDARD_CHROM_ONLY="$2"
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

if [[ "${REFERENCE_KIND}" != "bioconductor_packages" && "${REFERENCE_KIND}" != "fasta_gff" ]]; then
  echo "--reference-kind must be bioconductor_packages or fasta_gff." >&2
  exit 1
fi

# Common required options for both kinds.
common_required=(ORGANISM LABEL GENOME_BUILD IMAGE)

if [[ "${REFERENCE_KIND}" == "fasta_gff" ]]; then
  required_vars=("${common_required[@]}" GENOME_FASTA ANNOTATION_GFF)
else
  required_vars=("${common_required[@]}" GENOME_PACKAGE ANNOTATION_PACKAGE ANNOTATION_OBJECT)
fi

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name}" ]]; then
    echo "Missing required option for ${var_name} (reference-kind=${REFERENCE_KIND})" >&2
    usage >&2
    exit 1
  fi
done

if [[ "${STANDARD_CHROM_ONLY}" != "true" && "${STANDARD_CHROM_ONLY}" != "false" ]]; then
  echo "--standard-chrom-only must be either true or false." >&2
  exit 1
fi

CRAN_PACKAGES=("jsonlite" "${CRAN_PACKAGES[@]}")
BUILD_ONLY_PACKAGES=()

if [[ "${REFERENCE_KIND}" == "fasta_gff" ]]; then
  # Validate inputs exist on the host before assembling the build context.
  if [[ ! -f "${GENOME_FASTA}" ]]; then
    echo "--genome-fasta not found: ${GENOME_FASTA}" >&2
    exit 1
  fi
  if [[ ! -f "${ANNOTATION_GFF}" ]]; then
    echo "--annotation-gff not found: ${ANNOTATION_GFF}" >&2
    exit 1
  fi
  if [[ -n "${UNIPROT_MAP}" && ! -f "${UNIPROT_MAP}" ]]; then
    echo "--uniprot-map not found: ${UNIPROT_MAP}" >&2
    exit 1
  fi
  # A custom FASTA/GFF organism is never one of the built-in human/mouse ids, and
  # (unless a uniprot map is supplied) ships without ID maps. Imply the two build
  # flags so callers don't have to remember them.
  ALLOW_NON_BUILTIN="true"
  if [[ -z "${UNIPROT_MAP}" ]]; then
    ALLOW_MISSING_MAPS="true"
  fi
  # The forged BSgenome + the txdb2grangeslist transform need these only at build
  # time; they install into the default library, never the shipped rlib.
  BUILD_ONLY_PACKAGES+=("BSgenomeForge" "crisprDesign" "txdbmaker" "rtracklayer")
else
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

  # Bioconductor packages needed only at build time to produce annotation/txdb.rds.
  # These install into the builder's default library and are NOT shipped in rlib,
  # mirroring how github packages (e.g. crisprDesignData) are treated build-only.
  if [[ "${ANNOTATION_TRANSFORM}" == "txdb2grangeslist" ]]; then
    BUILD_ONLY_PACKAGES+=("crisprDesign")
  fi
  # When a normalized rds is shipped (annotation_loader=rds), the source annotation
  # package is only needed at build time. If it was listed among the runtime
  # packages, move it to the build-only set so it does not bloat the shipped rlib.
  if [[ "${ANNOTATION_LOADER}" == "rds" && -n "${ANNOTATION_PACKAGE}" ]]; then
    filtered_packages=()
    moved_annotation="false"
    for pkg in "${PACKAGES[@]}"; do
      if [[ "${pkg}" == "${ANNOTATION_PACKAGE}" ]]; then
        moved_annotation="true"
        continue
      fi
      filtered_packages+=("${pkg}")
    done
    if [[ "${moved_annotation}" == "true" ]]; then
      PACKAGES=("${filtered_packages[@]}")
      BUILD_ONLY_PACKAGES+=("${ANNOTATION_PACKAGE}")
    fi
  fi
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
if [[ "${#BUILD_ONLY_PACKAGES[@]}" -gt 0 ]]; then
  BUILD_ONLY_PACKAGES_R="$(package_r_vector "${BUILD_ONLY_PACKAGES[@]}")"
else
  BUILD_ONLY_PACKAGES_R=""
fi

COMPAT_ENV=""
if [[ "${ALLOW_NON_BUILTIN}" == "true" ]]; then
  COMPAT_ENV+="ENV PREDITR_ALLOW_NON_BUILTIN_REFERENCE=TRUE"$'\n'
fi
if [[ "${ALLOW_MISSING_MAPS}" == "true" ]]; then
  COMPAT_ENV+="ENV PREDITR_ALLOW_MISSING_MAPS=TRUE"$'\n'
fi

# The TxDb2GRangesList call for the rds/txdb2grangeslist path. standardChromOnly=FALSE
# skips GenomeInfoDb::keepStandardChromosomes(species=...), which fails for species with
# no UCSC seqlevels-style entry (e.g. Danio rerio, Gallus gallus).
if [[ "${STANDARD_CHROM_ONLY}" == "false" ]]; then
  TXDB2GRL_CALL='crisprDesign::TxDb2GRangesList(txdb, standardChromOnly = FALSE)'
else
  TXDB2GRL_CALL='crisprDesign::TxDb2GRangesList(txdb)'
fi

cp "${SCRIPT_DIR}/check_reference_compatibility.R" "${BUILD_DIR}/check_reference_compatibility.R"

if [[ "${REFERENCE_KIND}" == "fasta_gff" ]]; then
  ## ---- fasta_gff build context + Dockerfile ------------------------------
  cp "${SCRIPT_DIR}/build_reference_payload_fasta.R" "${BUILD_DIR}/build_reference_payload_fasta.R"
  cp "${SCRIPT_DIR}/generate_reference_maps.R" "${BUILD_DIR}/generate_reference_maps.R"
  mkdir -p "${BUILD_DIR}/inputs"

  FASTA_BASE="$(basename "${GENOME_FASTA}")"
  GFF_BASE="$(basename "${ANNOTATION_GFF}")"
  cp "${GENOME_FASTA}" "${BUILD_DIR}/inputs/${FASTA_BASE}"
  cp "${ANNOTATION_GFF}" "${BUILD_DIR}/inputs/${GFF_BASE}"
  GENOME_ORGANISM_EFF="${GENOME_ORGANISM:-${LABEL}}"

  # Optional maps step (only when a uniprot map is supplied).
  MAPS_STEP=""
  if [[ -n "${UNIPROT_MAP}" ]]; then
    UNIPROT_BASE="$(basename "${UNIPROT_MAP}")"
    cp "${UNIPROT_MAP}" "${BUILD_DIR}/inputs/${UNIPROT_BASE}"
    # dplyr/data.table are used by generate_reference_maps.R; add them build-only.
    BUILD_ONLY_PACKAGES+=("dplyr" "data.table")
    BUILD_ONLY_PACKAGES_R="$(package_r_vector "${BUILD_ONLY_PACKAGES[@]}")"
    MAPS_STEP=$(cat <<MAPSTEP
RUN Rscript /tmp/generate_reference_maps.R --organism "\${ORGANISM}" --maps-dir "/tmp/preditr-maps/\${ORGANISM}" --annotation-rds "\${PREDITR_REFERENCE_DIR}/annotation/txdb.rds" --uniprot-map "/tmp/inputs/${UNIPROT_BASE}"
RUN if [ -n "\$(ls -A /tmp/preditr-maps/\${ORGANISM} 2>/dev/null)" ]; then cp -a "/tmp/preditr-maps/\${ORGANISM}" "\${PREDITR_REFERENCE_DIR}/maps"; fi
MAPSTEP
)
  fi

  cat > "${DOCKERFILE}" <<DOCKERFILE
# ---- Stage 1: builder (full R/Bioconductor) — produces /image-refs/<organism> ----
# reference-kind: fasta_gff (genome FASTA + annotation GFF3/GTF; no Bioconductor
# genome/annotation packages). The BSgenome package is forged from the FASTA at
# build time; the annotation is built from the GFF with txdbmaker + crisprDesign.
FROM bioconductor/bioconductor_docker:${BIOC_VERSION} AS builder

ARG ORGANISM=${ORGANISM}
ARG ORGANISM_LABEL="${LABEL}"
ARG GENOME_BUILD="${GENOME_BUILD}"

ENV ORGANISM=\${ORGANISM}
ENV ORGANISM_LABEL=\${ORGANISM_LABEL}
ENV GENOME_BUILD=\${GENOME_BUILD}
ENV BIOC_VERSION=${BIOC_VERSION}
ENV GENOME_FASTA=/tmp/inputs/${FASTA_BASE}
ENV ANNOTATION_GFF=/tmp/inputs/${GFF_BASE}
ENV ANNOTATION_FORMAT=${ANNOTATION_FORMAT}
ENV GENOME_ORGANISM="${GENOME_ORGANISM_EFF}"
ENV GENOME_PROVIDER="${GENOME_PROVIDER}"
ENV STANDARD_CHROM_ONLY=${STANDARD_CHROM_ONLY}
ENV PREDITR_REFERENCE_DIR=/image-refs/\${ORGANISM}
ENV PREDITR_REFERENCE_RLIB=/image-refs/\${ORGANISM}/rlib

RUN mkdir -p "\${PREDITR_REFERENCE_RLIB}" "\${PREDITR_REFERENCE_DIR}" "\${PREDITR_REFERENCE_DIR}/annotation" "/tmp/preditr-maps/\${ORGANISM}"

RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager"); BiocManager::install(version = "${BIOC_VERSION}", ask = FALSE, update = FALSE)'

# jsonlite ships in rlib so the manifest loader / compatibility check can read it.
RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); cran_packages <- c(${CRAN_PACKAGES_R}); if (length(cran_packages) > 0) install.packages(cran_packages, lib = Sys.getenv("PREDITR_REFERENCE_RLIB"))'

# Build-only packages (BSgenomeForge, crisprDesign, txdbmaker, rtracklayer, and — when
# a uniprot map is supplied — dplyr/data.table) install into the default library, NOT
# the shipped rlib. The forged BSgenome package is the only thing added to rlib.
RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); build_only <- c(${BUILD_ONLY_PACKAGES_R}); if (length(build_only) > 0) BiocManager::install(build_only, ask = FALSE, update = FALSE)'

COPY build_reference_payload_fasta.R /tmp/build_reference_payload_fasta.R
COPY generate_reference_maps.R /tmp/generate_reference_maps.R
COPY inputs /tmp/inputs

# Forge the BSgenome package from the FASTA, build+normalize the annotation
# GRangesList from the GFF, and write the manifest.
RUN Rscript /tmp/build_reference_payload_fasta.R

${MAPS_STEP}

# Embed the exact Dockerfile used to build this reference into the payload.
COPY reference.Dockerfile /image-refs/${ORGANISM}/Dockerfile

${COMPAT_ENV}COPY check_reference_compatibility.R /tmp/check_reference_compatibility.R

RUN Rscript /tmp/check_reference_compatibility.R "\${PREDITR_REFERENCE_DIR}" /tmp/preditr-maps

# Strip help/docs/vignettes/tests from the shipped rlib — not needed at runtime.
RUN find "\${PREDITR_REFERENCE_RLIB}" -type d \( -name help -o -name html -o -name doc -o -name examples -o -name tests -o -name unitTests \) -exec rm -rf {} + 2>/dev/null || true

# ---- Stage 2: minimal carrier (no R) — only the payload + a shell to copy it ----
FROM debian:stable-slim
COPY --from=builder /image-refs/${ORGANISM} /image-refs/${ORGANISM}
CMD ["sh", "-c", "rm -rf /refs/${ORGANISM} && mkdir -p /refs && cp -a /image-refs/${ORGANISM} /refs/${ORGANISM}"]
DOCKERFILE

else
  ## ---- bioconductor_packages build context + Dockerfile ------------------
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

# Build-only Bioconductor packages (e.g. crisprDesign and the source TxDb) are
# needed only to produce annotation/txdb.rds. They install into the default
# library, NOT the shipped rlib, so they do not bloat the reference payload.
RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); build_only <- c(${BUILD_ONLY_PACKAGES_R}); if (length(build_only) > 0) BiocManager::install(build_only, ask = FALSE, update = FALSE)'

# GitHub packages (e.g. crisprDesignData) are only needed at build time to
# produce annotation/txdb.rds, so they install into the default library rather
# than the shipped rlib.
RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); gh <- c(${GITHUB_PACKAGES_R}); if (length(gh) > 0) { if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes"); remotes::install_github(gh, upgrade = "never") }'

RUN Rscript -e '.libPaths(c(Sys.getenv("PREDITR_REFERENCE_RLIB"), .libPaths())); if (identical(Sys.getenv("ANNOTATION_LOADER"), "rds")) { load_source <- function() { if (identical(Sys.getenv("ANNOTATION_SOURCE_LOADER"), "data")) { env <- new.env(parent = emptyenv()); utils::data(list = Sys.getenv("ANNOTATION_OBJECT"), package = Sys.getenv("ANNOTATION_PACKAGE"), envir = env); env[[Sys.getenv("ANNOTATION_OBJECT")]] } else { getExportedValue(Sys.getenv("ANNOTATION_PACKAGE"), Sys.getenv("ANNOTATION_OBJECT")) } }; txdb <- load_source(); if (identical(Sys.getenv("ANNOTATION_TRANSFORM"), "txdb2grangeslist")) { txdb <- ${TXDB2GRL_CALL} }; rds_path <- file.path(Sys.getenv("PREDITR_REFERENCE_DIR"), Sys.getenv("ANNOTATION_RDS_PATH")); dir.create(dirname(rds_path), recursive = TRUE, showWarnings = FALSE); saveRDS(txdb, rds_path) }'

RUN Rscript -e 'ref_dir <- Sys.getenv("PREDITR_REFERENCE_DIR"); manifest <- file.path(ref_dir, "preditr_reference.json"); packages <- c(${PACKAGES_R}); annotation_path_line <- if (identical(Sys.getenv("ANNOTATION_LOADER"), "rds")) paste0("  \\"annotation_path\\": \\"", Sys.getenv("ANNOTATION_RDS_PATH"), "\\"", ",") else NULL; lines <- c("{", "  \\"schema_version\\": \\"0.1\\",", paste0("  \\"organism_id\\": \\"", Sys.getenv("ORGANISM"), "\\"", ","), paste0("  \\"organism_label\\": \\"", Sys.getenv("ORGANISM_LABEL"), "\\"", ","), paste0("  \\"genome_build\\": \\"", Sys.getenv("GENOME_BUILD"), "\\"", ","), "  \\"reference_kind\\": \\"bioconductor_packages\\",", "  \\"bioconductor_version\\": \\"${BIOC_VERSION}\\",", "  \\"r_library_path\\": \\"rlib\\",", paste0("  \\"genome_package\\": \\"", Sys.getenv("GENOME_PACKAGE"), "\\"", ","), paste0("  \\"annotation_package\\": \\"", Sys.getenv("ANNOTATION_PACKAGE"), "\\"", ","), paste0("  \\"annotation_object\\": \\"", Sys.getenv("ANNOTATION_OBJECT"), "\\"", ","), paste0("  \\"annotation_loader\\": \\"", Sys.getenv("ANNOTATION_LOADER"), "\\"", ","), paste0("  \\"annotation_source_loader\\": \\"", Sys.getenv("ANNOTATION_SOURCE_LOADER"), "\\"", ","), paste0("  \\"annotation_transform\\": \\"", Sys.getenv("ANNOTATION_TRANSFORM"), "\\"", ","), annotation_path_line, "  \\"packages\\": [", paste0("    ", paste(sprintf("\\"%s\\"", packages), collapse = ",\\n    ")), "  ]", "}"); writeLines(lines, manifest)'

RUN Rscript -e '.libPaths(c(Sys.getenv("PREDITR_REFERENCE_RLIB"), .libPaths())); pkgs <- installed.packages(lib.loc = Sys.getenv("PREDITR_REFERENCE_RLIB")); utils::write.table(as.data.frame(pkgs[, c("Package", "Version", "LibPath")]), file = file.path(Sys.getenv("PREDITR_REFERENCE_DIR"), "installed_packages.tsv"), sep = "\\t", quote = FALSE, row.names = FALSE)'

RUN Rscript -e 'loader <- c("load_preditr_reference_payload <- function(reference_dir) {", "  manifest <- jsonlite::fromJSON(file.path(reference_dir, \\"preditr_reference.json\\"))", "  .libPaths(c(file.path(reference_dir, manifest\$r_library_path), .libPaths()))", "  requireNamespace(manifest\$genome_package, quietly = FALSE)", "  requireNamespace(manifest\$annotation_package, quietly = FALSE)", "  if (identical(manifest\$annotation_loader, \\"data\\")) {", "    env <- new.env(parent = emptyenv())", "    utils::data(list = manifest\$annotation_object, package = manifest\$annotation_package, envir = env)", "    txdb <- env[[manifest\$annotation_object]]", "  } else if (identical(manifest\$annotation_loader, \\"package-object\\")) {", "    txdb <- getExportedValue(manifest\$annotation_package, manifest\$annotation_object)", "  } else if (identical(manifest\$annotation_loader, \\"rds\\")) {", "    txdb <- readRDS(file.path(reference_dir, manifest\$annotation_path))", "  } else {", "    stop(\\"Unsupported annotation_loader: \\", manifest\$annotation_loader)", "  }", "  list(manifest = manifest, txdb = txdb, genome_package = manifest\$genome_package)", "}"); writeLines(loader, file.path(Sys.getenv("PREDITR_REFERENCE_DIR"), "reference_loader.R"))'

# Embed the exact Dockerfile used to build this reference into the payload, so each
# image self-documents how it was produced (organisms needing the seqstyle workaround
# ship a different Dockerfile than the standard ones).
COPY reference.Dockerfile /image-refs/${ORGANISM}/Dockerfile

${COMPAT_ENV}COPY check_reference_compatibility.R /tmp/check_reference_compatibility.R
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

fi

# Provide the generated Dockerfile to the build context so the COPY step above can
# embed it into the image at /image-refs/<organism>/Dockerfile.
cp "${DOCKERFILE}" "${BUILD_DIR}/reference.Dockerfile"

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
