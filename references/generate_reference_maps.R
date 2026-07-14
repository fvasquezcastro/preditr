#!/usr/bin/env Rscript
#
# generate_reference_maps.R
# -------------------------
# Organism-agnostic builder for the ID maps PrEditR consumes at runtime. Replaces
# the two byte-identical maps/{human,mouse}/create_maps.R scripts with a single
# parameterized generator that references/build_reference_image.sh runs for every
# organism, so adding an organism needs no new script.
#
# Produces, under --maps-dir:
#   ensembl_to_uniprot.rds   (hashed env: Ensembl transcript ID -> UniProt ID)
#   uniprot_to_ensembl.rds   (hashed env: UniProt ID -> Ensembl transcript ID)
#   has_isoforms.rds         (hashed env: Swiss-Prot IDs that have isoforms)
#   duplicated_uniprot.rds   (character vector of duplicated canonical Swiss-Prot IDs)
#   ensembl_in_txdb.txt      (transcript IDs present in the annotation object)
#
# Inputs:
#   --organism       Organism id (used only for messages).
#   --maps-dir       Output directory (e.g. /image-refs/<organism>/maps).
#   --annotation-rds Path to the normalized annotation GRangesList (annotation/txdb.rds).
#                    Its transcript IDs define which BioMart rows are kept, so the
#                    map always matches the shipped annotation.
#   --biomart-export Optional path to a pre-downloaded BioMart TSV(.gz) with columns
#                    Transcript.stable.ID, UniProtKB.isoform.ID,
#                    UniProtKB.Swiss.Prot.ID, Ensembl.Canonical.
#   --biomart-dataset Optional Ensembl dataset (e.g. hsapiens_gene_ensembl). When
#                    --biomart-export is absent, the equivalent columns are pulled
#                    live via the biomaRt package.
#
# Exactly one of --biomart-export / --biomart-dataset must be provided.
#
# Usage:
#   Rscript references/generate_reference_maps.R \
#     --organism human --maps-dir /image-refs/human/maps \
#     --annotation-rds /image-refs/human/annotation/txdb.rds \
#     --biomart-dataset hsapiens_gene_ensembl

suppressWarnings(suppressMessages({
  library(dplyr)
  library(data.table)
}))

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag) {
  i <- which(args == flag)
  if (length(i) == 1 && i < length(args)) args[i + 1] else NA_character_
}

organism        <- get_arg("--organism")
maps_dir        <- get_arg("--maps-dir")
annotation_rds  <- get_arg("--annotation-rds")
biomart_export  <- get_arg("--biomart-export")
biomart_dataset <- get_arg("--biomart-dataset")

if (is.na(organism) || is.na(maps_dir) || is.na(annotation_rds)) {
  stop("Required: --organism, --maps-dir, --annotation-rds")
}
if (is.na(biomart_export) && is.na(biomart_dataset)) {
  stop("Provide either --biomart-export <file> or --biomart-dataset <ensembl dataset>")
}
if (!dir.exists(maps_dir)) dir.create(maps_dir, recursive = TRUE, showWarnings = FALSE)

### ------------------------------------------------------------------
### 1. Transcript IDs present in the shipped annotation object
### ------------------------------------------------------------------
message("[", organism, "] reading annotation: ", annotation_rds)
txdb <- readRDS(annotation_rds)
# crisprDesignData-style GRangesList: transcript IDs live on $transcripts$tx_id.
ensembl_ids <- tryCatch(unique(txdb$transcripts$tx_id), error = function(e) NULL)
if (is.null(ensembl_ids) || length(ensembl_ids) == 0) {
  # Fall back to any tx_id column across the flattened object.
  ensembl_ids <- unique(unlist(txdb)$tx_id)
}
ensembl_ids <- ensembl_ids[!is.na(ensembl_ids) & nzchar(ensembl_ids)]
writeLines(as.character(ensembl_ids), file.path(maps_dir, "ensembl_in_txdb.txt"))
message("[", organism, "] transcripts in annotation: ", length(ensembl_ids))

### ------------------------------------------------------------------
### 2. Obtain the BioMart UniProt cross-reference table
### ------------------------------------------------------------------
if (!is.na(biomart_export)) {
  message("[", organism, "] reading BioMart export: ", biomart_export)
  con <- if (grepl("\\.gz$", biomart_export)) gzfile(biomart_export) else biomart_export
  biomart <- read.table(con, header = TRUE, sep = "\t")
} else {
  message("[", organism, "] querying biomaRt dataset: ", biomart_dataset)
  if (!requireNamespace("biomaRt", quietly = TRUE)) {
    stop("biomaRt is required for --biomart-dataset but is not installed.")
  }
  mart <- biomaRt::useEnsembl(biomart = "genes", dataset = biomart_dataset)
  raw <- biomaRt::getBM(
    attributes = c("ensembl_transcript_id", "uniprot_isoform",
                   "uniprotswissprot", "transcript_is_canonical"),
    mart = mart
  )
  # Normalize to the same column names the pre-downloaded export uses.
  biomart <- data.frame(
    Transcript.stable.ID     = raw$ensembl_transcript_id,
    UniProtKB.isoform.ID     = ifelse(is.na(raw$uniprot_isoform), "", raw$uniprot_isoform),
    UniProtKB.Swiss.Prot.ID  = ifelse(is.na(raw$uniprotswissprot), "", raw$uniprotswissprot),
    Ensembl.Canonical        = ifelse(is.na(raw$transcript_is_canonical), 0, raw$transcript_is_canonical),
    stringsAsFactors = FALSE
  )
}

biomart <- biomart[biomart$Transcript.stable.ID %in% ensembl_ids, ]

biomart$selected_uniprot <- ifelse(
  nzchar(biomart$UniProtKB.isoform.ID),
  biomart$UniProtKB.isoform.ID,
  biomart$UniProtKB.Swiss.Prot.ID
)

### ------------------------------------------------------------------
### 3. ENSEMBL -> UNIPROT (isoform-aware, 1-to-1)
### ------------------------------------------------------------------
ensembl_to_uniprot <- new.env(hash = TRUE, parent = emptyenv())
for (i in seq_len(nrow(biomart))) {
  ensembl_to_uniprot[[biomart$Transcript.stable.ID[i]]] <- biomart$selected_uniprot[i]
}
saveRDS(ensembl_to_uniprot, file.path(maps_dir, "ensembl_to_uniprot.rds"), compress = "xz")

fwrite(
  biomart %>% mutate(UNIPROT_ID = selected_uniprot),
  file.path(maps_dir, "ensembl_to_uniprot.txt.gz"),
  sep = "\t", quote = FALSE, compress = "gzip"
)

### ------------------------------------------------------------------
### 4. UNIPROT -> ENSEMBL (canonical fallback when no isoform given)
### ------------------------------------------------------------------
uniprot_to_ensembl <- new.env(hash = TRUE, parent = emptyenv())
for (i in seq_len(nrow(biomart))) {
  key <- biomart$selected_uniprot[i]
  if (!nzchar(key)) next
  uniprot_to_ensembl[[key]] <- biomart$Transcript.stable.ID[i]
}
biomart_canonical <- biomart[which(biomart$Ensembl.Canonical == 1), ]
for (i in seq_len(nrow(biomart_canonical))) {
  key <- biomart_canonical$UniProtKB.Swiss.Prot.ID[i]
  if (!nzchar(key)) next
  uniprot_to_ensembl[[key]] <- biomart_canonical$Transcript.stable.ID[i]
}
saveRDS(uniprot_to_ensembl, file.path(maps_dir, "uniprot_to_ensembl.rds"), compress = "xz")

### ------------------------------------------------------------------
### 5. Base UniProt IDs that have isoforms (for flagging)
### ------------------------------------------------------------------
has_isoforms <- new.env(hash = TRUE, parent = emptyenv())
for (id in unique(biomart$UniProtKB.Swiss.Prot.ID[nzchar(biomart$UniProtKB.isoform.ID)])) {
  has_isoforms[[id]] <- TRUE
}
saveRDS(has_isoforms, file.path(maps_dir, "has_isoforms.rds"), compress = "xz")

### ------------------------------------------------------------------
### 6. Duplicated canonical UniProt IDs
### ------------------------------------------------------------------
all_uniprot <- as.vector(biomart$UniProtKB.Swiss.Prot.ID)
duplicated_uniprot <- unique(all_uniprot[duplicated(all_uniprot)])
saveRDS(duplicated_uniprot, file.path(maps_dir, "duplicated_uniprot.rds"))

message("[", organism, "] maps written to ", maps_dir)
