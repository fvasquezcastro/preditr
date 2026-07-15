#!/usr/bin/env Rscript
#
# build_reference_payload_fasta.R
# -------------------------------
# Container-side builder for the `fasta_gff` reference kind. Turns a user-supplied
# genome FASTA + annotation GFF3/GTF into the same payload the package-based path
# produces (a forged BSgenome package in rlib/ plus a normalized crisprDesignData-
# style GRangesList at annotation/txdb.rds), then writes the discovery manifest.
#
# It is copied into the build context and run by references/build_reference_image.sh
# inside the Bioconductor builder stage. All parameters arrive as environment
# variables so the Dockerfile stays declarative:
#
#   ORGANISM, ORGANISM_LABEL, GENOME_BUILD   organism identity / manifest fields
#   BIOC_VERSION                             Bioconductor version (manifest field)
#   PREDITR_REFERENCE_DIR                    output payload dir (/image-refs/<org>)
#   PREDITR_REFERENCE_RLIB                   shipped R library (…/rlib)
#   GENOME_FASTA                             path to the genome FASTA(.gz)
#   ANNOTATION_GFF                           path to the annotation GFF3/GTF(.gz)
#   ANNOTATION_FORMAT                        gff3 | gtf | auto (default auto)
#   GENOME_ORGANISM                          binomial used to name the BSgenome pkg
#   GENOME_PROVIDER                          provider token in the pkg name
#   STANDARD_CHROM_ONLY                      true|false for TxDb2GRangesList
#
# The forged BSgenome package name is auto-derived by BSgenomeForge from the
# organism binomial + provider + build, so it is read back from disk and written
# into the manifest (both genome_package and annotation_package point at it: the
# annotation is an rds, and the package just has to be a loadable namespace).

suppressWarnings(suppressMessages({
  library(Biostrings)
  library(rtracklayer)
  library(GenomicRanges)
  library(GenomeInfoDb)
  library(S4Vectors)
}))

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

env <- function(name, default = NA_character_) {
  v <- Sys.getenv(name, unset = "")
  if (nzchar(v)) v else default
}

organism      <- env("ORGANISM")
label         <- env("ORGANISM_LABEL", organism)
genome_build  <- env("GENOME_BUILD", organism)
bioc_version  <- env("BIOC_VERSION", "3.19")
ref_dir       <- env("PREDITR_REFERENCE_DIR")
rlib          <- env("PREDITR_REFERENCE_RLIB", file.path(ref_dir, "rlib"))
fasta         <- env("GENOME_FASTA")
gff           <- env("ANNOTATION_GFF")
gff_format    <- tolower(env("ANNOTATION_FORMAT", "auto"))
genome_org    <- env("GENOME_ORGANISM", label)
provider      <- env("GENOME_PROVIDER", "custom")
standard_only <- tolower(env("STANDARD_CHROM_ONLY", "true")) %in% c("true", "1", "yes")

stopifnot(nzchar(organism), nzchar(ref_dir), nzchar(fasta), nzchar(gff))
if (!file.exists(fasta)) stop("Genome FASTA not found: ", fasta)
if (!file.exists(gff))   stop("Annotation GFF/GTF not found: ", gff)

dir.create(rlib, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(ref_dir, "annotation"), recursive = TRUE, showWarnings = FALSE)

if (identical(gff_format, "auto")) {
  gff_format <- if (grepl("\\.gtf(\\.gz)?$", gff, ignore.case = TRUE)) "gtf" else "gff3"
}
message("[", organism, "] annotation format: ", gff_format)

## ---------------------------------------------------------------------------
## 1. FASTA -> cleaned 2bit -> forge + install BSgenome package into rlib/
## ---------------------------------------------------------------------------
message("[", organism, "] reading genome FASTA ...")
dna <- readDNAStringSet(fasta)
# FASTA headers often carry a description after the first token (">chr1 AC:..."),
# but the GFF seqnames are the bare token. Trim so genome and annotation agree.
names(dna) <- sub("\\s.*$", "", names(dna))
if (anyDuplicated(names(dna))) stop("Duplicate sequence names in FASTA after trimming descriptions.")
message("[", organism, "] sequences: ", length(dna), " (", paste(head(names(dna), 5), collapse = ", "),
        if (length(dna) > 5) ", ..." else "", ")")

twobit <- file.path(tempdir(), paste0(organism, ".2bit"))
export.2bit(dna, twobit)

# BSgenomeForge builds the package name from the organism binomial; it expects a
# genus + species. Pad a single-word label so naming succeeds.
if (!grepl("\\s", trimws(genome_org))) genome_org <- paste(trimws(genome_org), "sp")

pkgroot <- file.path(tempdir(), "pkgsrc")
unlink(pkgroot, recursive = TRUE); dir.create(pkgroot, showWarnings = FALSE)
message("[", organism, "] forging BSgenome package (organism='", genome_org,
        "', provider='", provider, "', genome='", genome_build, "') ...")
BSgenomeForge::forgeBSgenomeDataPkgFromTwobitFile(
  filepath        = twobit,
  organism        = genome_org,
  provider        = provider,
  genome          = genome_build,
  pkg_maintainer  = "PrEditR reference builder <preditr@lji.org>",
  destdir         = pkgroot,
  seqnames        = names(dna)
)
srcdir <- list.dirs(pkgroot, recursive = FALSE)[1]
genome_package <- basename(srcdir)
message("[", organism, "] forged package: ", genome_package)

install_log <- system2("R", c("CMD", "INSTALL", paste0("--library=", rlib), srcdir),
                       stdout = TRUE, stderr = TRUE)
if (!identical(attr(install_log, "status") %||% 0L, 0L)) {
  cat(install_log, sep = "\n")
  stop("R CMD INSTALL of forged BSgenome package failed.")
}
message("[", organism, "] installed forged BSgenome into rlib/")

.libPaths(c(rlib, .libPaths()))
genome_obj <- getExportedValue(genome_package, genome_package)

## ---------------------------------------------------------------------------
## 2. GFF/GTF -> TxDb -> crisprDesignData-style GRangesList
## ---------------------------------------------------------------------------
si <- Seqinfo(seqnames = names(dna), seqlengths = width(dna),
              isCircular = rep(FALSE, length(dna)), genome = genome_build)

message("[", organism, "] building TxDb from annotation ...")
txdb_raw <- txdbmaker::makeTxDbFromGFF(
  gff, format = gff_format, chrominfo = si,
  dataSource = paste0("PrEditR:", organism),
  organism   = NA_character_  # skip NCBI taxonomy validation (arbitrary organisms)
)

message("[", organism, "] converting to GRangesList (standardChromOnly=", standard_only, ") ...")
grl <- if (standard_only) {
  crisprDesign::TxDb2GRangesList(txdb_raw)
} else {
  crisprDesign::TxDb2GRangesList(txdb_raw, standardChromOnly = FALSE)
}

## ---------------------------------------------------------------------------
## 3. Normalize: strip GFF type prefixes; inject gene_symbol from GFF names
## ---------------------------------------------------------------------------
strip_prefix <- function(x) sub("^[A-Za-z_]+:", "", x)

# Build a gene_id -> symbol lookup from the annotation's own name attributes.
# GFF3 exposes Name on gene records; GTF exposes gene_name on every record.
gff_all <- rtracklayer::import(gff)
gmc <- S4Vectors::mcols(gff_all)
gene_recs <- if ("type" %in% names(gmc)) gff_all[as.character(gmc$type) %in% c("gene")] else gff_all
gmc <- S4Vectors::mcols(gene_recs)
id_col   <- intersect(c("gene_id", "ID"), names(gmc))[1]
name_col <- intersect(c("gene_name", "Name", "gene"), names(gmc))[1]
sym_map <- character(0)
if (!is.na(id_col) && !is.na(name_col) && length(gene_recs) > 0) {
  keys <- strip_prefix(as.character(gmc[[id_col]]))
  vals <- as.character(gmc[[name_col]])
  keep <- !is.na(keys) & nzchar(keys) & !is.na(vals) & nzchar(vals)
  sym_map <- setNames(vals[keep], keys[keep])
  sym_map <- sym_map[!duplicated(names(sym_map))]
}
message("[", organism, "] gene_symbol lookup entries: ", length(sym_map))

grl <- S4Vectors::endoapply(grl, function(gr) {
  mc <- S4Vectors::mcols(gr)
  if ("tx_id" %in% names(mc))   gr$tx_id   <- strip_prefix(as.character(gr$tx_id))
  if ("gene_id" %in% names(mc)) {
    gid <- strip_prefix(as.character(gr$gene_id))
    gr$gene_id <- gid
    sym <- unname(sym_map[gid])
    sym[is.na(sym) | !nzchar(sym)] <- gid[is.na(sym) | !nzchar(sym)]  # fall back to gene_id
    gr$gene_symbol <- sym
  }
  gr
})

annotation_rds <- file.path(ref_dir, "annotation", "txdb.rds")
saveRDS(grl, annotation_rds)
message("[", organism, "] wrote ", annotation_rds,
        " | features: ", paste(names(grl), collapse = ", "))

## ---------------------------------------------------------------------------
## 4. Manifest + installed_packages.tsv + reference_loader.R
## ---------------------------------------------------------------------------
json_str <- function(x) paste0('"', gsub('"', '\\\\"', x), '"')
manifest_lines <- c(
  "{",
  paste0("  ", json_str("schema_version"),        ": ", json_str("0.1"), ","),
  paste0("  ", json_str("organism_id"),            ": ", json_str(organism), ","),
  paste0("  ", json_str("organism_label"),         ": ", json_str(label), ","),
  paste0("  ", json_str("genome_build"),           ": ", json_str(genome_build), ","),
  paste0("  ", json_str("reference_kind"),         ": ", json_str("fasta_gff"), ","),
  paste0("  ", json_str("bioconductor_version"),   ": ", json_str(bioc_version), ","),
  paste0("  ", json_str("r_library_path"),         ": ", json_str("rlib"), ","),
  paste0("  ", json_str("genome_package"),         ": ", json_str(genome_package), ","),
  paste0("  ", json_str("annotation_package"),     ": ", json_str(genome_package), ","),
  paste0("  ", json_str("annotation_object"),      ": ", json_str("grangeslist"), ","),
  paste0("  ", json_str("annotation_loader"),      ": ", json_str("rds"), ","),
  paste0("  ", json_str("annotation_source_loader"),": ", json_str("gff"), ","),
  paste0("  ", json_str("annotation_transform"),   ": ", json_str("txdb2grangeslist"), ","),
  paste0("  ", json_str("annotation_path"),        ": ", json_str("annotation/txdb.rds"), ","),
  paste0("  ", json_str("packages"), ": ["),
  paste0("    ", json_str(genome_package)),
  "  ]",
  "}"
)
writeLines(manifest_lines, file.path(ref_dir, "preditr_reference.json"))

pkgs <- installed.packages(lib.loc = rlib)
utils::write.table(
  as.data.frame(pkgs[, c("Package", "Version", "LibPath"), drop = FALSE]),
  file = file.path(ref_dir, "installed_packages.tsv"),
  sep = "\t", quote = FALSE, row.names = FALSE
)

# Image-side loader kept in sync with the package-path builder for self-documentation.
loader <- c(
  "load_preditr_reference_payload <- function(reference_dir) {",
  "  manifest <- jsonlite::fromJSON(file.path(reference_dir, \"preditr_reference.json\"))",
  "  .libPaths(c(file.path(reference_dir, manifest$r_library_path), .libPaths()))",
  "  requireNamespace(manifest$genome_package, quietly = FALSE)",
  "  txdb <- readRDS(file.path(reference_dir, manifest$annotation_path))",
  "  genome <- getExportedValue(manifest$genome_package, manifest$genome_package)",
  "  list(manifest = manifest, txdb = txdb, genome = genome)",
  "}"
)
writeLines(loader, file.path(ref_dir, "reference_loader.R"))

message("[", organism, "] fasta_gff payload complete at ", ref_dir)
