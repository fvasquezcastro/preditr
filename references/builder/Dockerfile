# PrEditR reference-builder image: fvasquezcastro/preditr-ref:ref-builder
#
# A self-contained image that turns a genome FASTA + annotation GFF3/GTF (+ an
# optional UniProt<->transcript map) into a validated PrEditR reference payload
# DIRECTORY. The whole R/Bioconductor toolchain is baked in, so operators run a
# single `docker run` and never install packages themselves.
#
# Build (from the repo root):
#   references/build_builder_image.sh
# or:
#   docker build -f references/builder/Dockerfile -t fvasquezcastro/preditr-ref:ref-builder references
#
# Use:
#   docker run --rm -u "$(id -u):$(id -g)" -v /data:/in:ro -v "$PWD/refs":/out \
#     fvasquezcastro/preditr-ref:ref-builder \
#     --organism newt --label Newt --genome-build newt1 \
#     --genome-fasta /in/newt.fa --annotation-gff /in/newt.gff3
#
# Must match the Bioconductor version of the PrEditR app image so the shipped
# forged BSgenome package loads at runtime (loadReference asserts this).
ARG BIOC_VERSION=3.19
FROM bioconductor/bioconductor_docker:${BIOC_VERSION}

ENV PREDITR_BUILDER_HOME=/opt/preditr

# Bake the full build toolchain into the default site library:
#   BSgenomeForge  - forge a BSgenome package from the FASTA
#   txdbmaker      - makeTxDbFromGFF
#   crisprDesign   - TxDb2GRangesList (crisprDesignData-style GRangesList)
#   rtracklayer    - export.2bit + GFF import for gene_symbol lookup
#   dplyr/data.table - used by generate_reference_maps.R
#   jsonlite       - manifest / compatibility check
RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); \
      BiocManager::install(c("BSgenomeForge", "crisprDesign", "txdbmaker", "rtracklayer", \
                             "Biostrings", "BSgenome", "GenomicFeatures", "GenomeInfoDb", \
                             "S4Vectors", "GenomicRanges", "BiocGenerics", "IRanges"), \
                           ask = FALSE, update = FALSE); \
      install.packages(c("jsonlite", "dplyr", "data.table"))'

RUN mkdir -p ${PREDITR_BUILDER_HOME}
# The actual build logic is the same scripts the image-based builder uses, so
# there is a single source of truth for how a payload is produced.
COPY build_reference_payload_fasta.R ${PREDITR_BUILDER_HOME}/build_reference_payload_fasta.R
COPY generate_reference_maps.R       ${PREDITR_BUILDER_HOME}/generate_reference_maps.R
COPY check_reference_compatibility.R ${PREDITR_BUILDER_HOME}/check_reference_compatibility.R
COPY builder/build_reference_dir.sh  /usr/local/bin/build-reference
RUN chmod +x /usr/local/bin/build-reference

WORKDIR /out
ENTRYPOINT ["/usr/local/bin/build-reference"]
CMD ["--help"]
