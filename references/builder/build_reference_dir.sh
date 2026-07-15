#!/usr/bin/env bash
#
# build-reference — entrypoint for the PrEditR reference-builder image
# (fvasquezcastro/preditr-ref:ref-builder).
#
# Turns a genome FASTA + annotation GFF3/GTF (+ an optional UniProt<->transcript
# map) into a validated PrEditR reference payload DIRECTORY under /out/<organism>.
# All R/Bioconductor packages are baked into this image, so the caller installs
# nothing and only needs `docker run`.
#
# Typical use:
#   docker run --rm -u "$(id -u):$(id -g)" \
#     -v /data:/in:ro -v "$PWD/refs":/out \
#     fvasquezcastro/preditr-ref:ref-builder \
#     --organism newt --label Newt --genome-build newt1 \
#     --genome-fasta /in/newt.fa --annotation-gff /in/newt.gff3 \
#     --uniprot-map /in/newt_uniprot.tsv
#
# Then point the app at the directory:
#   PREDITR_REFERENCES_PATH="$PWD/refs"
set -euo pipefail

# R needs a writable HOME when the container runs as an arbitrary host uid.
export HOME="${HOME:-/tmp}"
[ -w "${HOME}" ] || export HOME=/tmp

PREDITR_BUILDER_HOME="${PREDITR_BUILDER_HOME:-/opt/preditr}"
BIOC_VERSION="${BIOC_VERSION:-3.19}"

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  cat <<'OPTS'

Options:
  --organism VALUE          Stable organism id (directory name under /out). Required.
  --genome-fasta VALUE      Path to the genome FASTA (.fa/.fa.gz). Required.
  --annotation-gff VALUE    Path to the annotation GFF3/GTF (.gff3/.gtf[.gz]). Required.
  --uniprot-map VALUE       Optional UniProt<->transcript TSV enabling UniProt-ID input.
                            Columns: transcript_id, uniprot_id[, is_canonical, isoform_of].
  --label VALUE             User-facing organism label. Default: --organism.
  --genome-build VALUE      Genome build label. Default: --organism.
  --annotation-format VALUE gff3 | gtf | auto. Default auto (from extension).
  --genome-organism VALUE   Binomial used only to name the forged BSgenome package.
                            Default: --label.
  --provider VALUE          Provider token in the forged package name. Default: custom.
  --standard-chrom-only V   true|false for TxDb2GRangesList. Default true. Set false for
                            species with no GenomeInfoDb UCSC seqlevels-style entry.
  --out VALUE               Output base directory. Default: /out.
  -h, --help                Show this help.
OPTS
}

ORGANISM=""; LABEL=""; GENOME_BUILD=""
GENOME_FASTA=""; ANNOTATION_GFF=""; UNIPROT_MAP=""
ANNOTATION_FORMAT="auto"; GENOME_ORGANISM=""; GENOME_PROVIDER="custom"
STANDARD_CHROM_ONLY="true"; OUT_BASE="/out"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --organism)          ORGANISM="$2"; shift 2 ;;
    --label)             LABEL="$2"; shift 2 ;;
    --genome-build)      GENOME_BUILD="$2"; shift 2 ;;
    --genome-fasta)      GENOME_FASTA="$2"; shift 2 ;;
    --annotation-gff)    ANNOTATION_GFF="$2"; shift 2 ;;
    --annotation-format) ANNOTATION_FORMAT="$2"; shift 2 ;;
    --uniprot-map)       UNIPROT_MAP="$2"; shift 2 ;;
    --genome-organism)   GENOME_ORGANISM="$2"; shift 2 ;;
    --provider)          GENOME_PROVIDER="$2"; shift 2 ;;
    --standard-chrom-only) STANDARD_CHROM_ONLY="$2"; shift 2 ;;
    --out)               OUT_BASE="$2"; shift 2 ;;
    -h|--help)           usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for v in ORGANISM GENOME_FASTA ANNOTATION_GFF; do
  if [[ -z "${!v}" ]]; then
    echo "ERROR: missing required option --$(echo "$v" | tr 'A-Z_' 'a-z-')" >&2
    usage >&2
    exit 1
  fi
done
[[ -f "${GENOME_FASTA}" ]]   || { echo "ERROR: --genome-fasta not found: ${GENOME_FASTA}" >&2; exit 1; }
[[ -f "${ANNOTATION_GFF}" ]] || { echo "ERROR: --annotation-gff not found: ${ANNOTATION_GFF}" >&2; exit 1; }
if [[ -n "${UNIPROT_MAP}" && ! -f "${UNIPROT_MAP}" ]]; then
  echo "ERROR: --uniprot-map not found: ${UNIPROT_MAP}" >&2; exit 1
fi

LABEL="${LABEL:-${ORGANISM}}"
GENOME_BUILD="${GENOME_BUILD:-${ORGANISM}}"
REF_DIR="${OUT_BASE}/${ORGANISM}"
MAPS_STAGING="/tmp/preditr-maps"

rm -rf "${REF_DIR}"
mkdir -p "${REF_DIR}/annotation" "${REF_DIR}/rlib" "${MAPS_STAGING}/${ORGANISM}"

echo ">> Building PrEditR reference payload for '${ORGANISM}' -> ${REF_DIR}"

# 1 + 2 + 3: forge BSgenome, build+normalize annotation, write manifest.
ORGANISM="${ORGANISM}" \
ORGANISM_LABEL="${LABEL}" \
GENOME_BUILD="${GENOME_BUILD}" \
BIOC_VERSION="${BIOC_VERSION}" \
PREDITR_REFERENCE_DIR="${REF_DIR}" \
PREDITR_REFERENCE_RLIB="${REF_DIR}/rlib" \
GENOME_FASTA="${GENOME_FASTA}" \
ANNOTATION_GFF="${ANNOTATION_GFF}" \
ANNOTATION_FORMAT="${ANNOTATION_FORMAT}" \
GENOME_ORGANISM="${GENOME_ORGANISM:-${LABEL}}" \
GENOME_PROVIDER="${GENOME_PROVIDER}" \
STANDARD_CHROM_ONLY="${STANDARD_CHROM_ONLY}" \
  Rscript "${PREDITR_BUILDER_HOME}/build_reference_payload_fasta.R"

# 4: ID maps from the UniProt TSV (optional).
if [[ -n "${UNIPROT_MAP}" ]]; then
  echo ">> Building ID maps from ${UNIPROT_MAP}"
  Rscript "${PREDITR_BUILDER_HOME}/generate_reference_maps.R" \
    --organism "${ORGANISM}" \
    --maps-dir "${MAPS_STAGING}/${ORGANISM}" \
    --annotation-rds "${REF_DIR}/annotation/txdb.rds" \
    --uniprot-map "${UNIPROT_MAP}"
  if [[ -n "$(ls -A "${MAPS_STAGING}/${ORGANISM}" 2>/dev/null)" ]]; then
    mkdir -p "${REF_DIR}/maps"
    cp -a "${MAPS_STAGING}/${ORGANISM}/." "${REF_DIR}/maps/"
  fi
fi

# 5: validate the payload with the same gate the image build uses.
export PREDITR_ALLOW_NON_BUILTIN_REFERENCE=TRUE
if [[ -z "${UNIPROT_MAP}" ]]; then
  export PREDITR_ALLOW_MISSING_MAPS=TRUE
fi
echo ">> Validating payload"
Rscript "${PREDITR_BUILDER_HOME}/check_reference_compatibility.R" "${REF_DIR}" "${MAPS_STAGING}"

# Trim rlib docs/help/tests to keep the payload small.
find "${REF_DIR}/rlib" -type d \( -name help -o -name html -o -name doc -o -name examples -o -name tests -o -name unitTests \) -exec rm -rf {} + 2>/dev/null || true

echo ">> Done. Reference payload at ${REF_DIR}"
echo ">> Run the app with:  PREDITR_REFERENCES_PATH=${OUT_BASE}"
