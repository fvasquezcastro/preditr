#!/usr/bin/env Rscript
#
# build_plddt_map.R
# -----------------
# Builds the per-organism AlphaFold pLDDT lookup consumed by functions/lookupPLDDT.R.
#
# Output: maps/<organism>/plddt.rds
#   A named list keyed by canonical UniProt accession (e.g. "P04637") ->
#   numeric vector of per-residue pLDDT, indexed by residue number (position 1 = element 1).
#   This file is excluded from the app image (.dockerignore) and instead ships in the
#   per-organism reference image, which copies maps/<organism>/ wholesale
#   (references/build_reference_image.sh). At runtime the app reads it from
#   <PREDITR_REFERENCES_PATH>/<organism>/maps/plddt.rds. So build it before building
#   that organism's reference image.
#
# Input: the AlphaFold DB bulk proteome archive for the organism. Download once from
#   https://ftp.ebi.ac.uk/pub/databases/alphafold/latest/
#     human: UP000005640_9606_HUMAN_v4.tar
#     mouse: UP000000589_10090_MOUSE_v4.tar
#   The tar holds one gzipped mmCIF per protein: AF-<ACCESSION>-F1-model_v4.cif.gz
#   pLDDT is stored as the B-factor of every atom; we read it off the CA atom of each residue.
#
# Usage:
#   Rscript maps/build_plddt_map.R --organism human --archive /path/to/UP000005640_9606_HUMAN_v4.tar
#   # or point at a directory of already-extracted *.cif.gz files:
#   Rscript maps/build_plddt_map.R --organism mouse --dir /path/to/extracted_cifs
#
# Only base R is required.

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag) {
  i <- which(args == flag)
  if (length(i) == 1 && i < length(args)) args[i + 1] else NA_character_
}

organism <- get_arg("--organism")
archive  <- get_arg("--archive")
cif_dir  <- get_arg("--dir")

if (is.na(organism) || !(organism %in% c("human", "mouse"))) {
  stop("Provide --organism human|mouse")
}
if (is.na(archive) && is.na(cif_dir)) {
  stop("Provide either --archive <tar> or --dir <directory of *.cif.gz>")
}

#Extract the tar into a temp dir if an archive was given.
if (!is.na(archive)) {
  cif_dir <- tempfile("af_proteome_")
  dir.create(cif_dir)
  message("Extracting ", archive, " -> ", cif_dir)
  utils::untar(archive, exdir = cif_dir)
}

cif_files <- list.files(cif_dir, pattern = "model_v4\\.cif\\.gz$", full.names = TRUE, recursive = TRUE)
if (length(cif_files) == 0) {
  stop("No '*-model_v4.cif.gz' files found under ", cif_dir)
}
message("Found ", length(cif_files), " model files.")

#Pull per-residue pLDDT (CA-atom B-factor) out of one mmCIF file.
#Parses the _atom_site loop generically so column order does not matter.
parse_plddt <- function(path) {

  lines <- readLines(gzfile(path), warn = FALSE)

  #Locate the _atom_site column headers, in order.
  header_idx <- grep("^_atom_site\\.", lines)
  if (length(header_idx) == 0) return(NULL)

  columns <- sub("^_atom_site\\.", "", trimws(lines[header_idx]))
  col <- function(name) which(columns == name)

  c_atom  <- col("label_atom_id")
  c_seq   <- col("label_seq_id")
  c_bfac  <- col("B_iso_or_equiv")
  if (length(c_atom) != 1 || length(c_seq) != 1 || length(c_bfac) != 1) return(NULL)

  #Atom records follow the header block, up to the next loop/category marker.
  first_data <- max(header_idx) + 1
  end <- first_data
  while (end <= length(lines) &&
         !grepl("^(loop_|_|#|data_)", lines[end]) &&
         nzchar(trimws(lines[end]))) {
    end <- end + 1
  }
  records <- lines[first_data:(end - 1)]
  records <- records[grepl("^ATOM|^HETATM", records)]
  if (length(records) == 0) return(NULL)

  fields <- strsplit(trimws(records), "\\s+")
  keep   <- vapply(fields, function(f) length(f) >= max(c_atom, c_seq, c_bfac) &&
                                       f[c_atom] == "CA", logical(1))
  fields <- fields[keep]
  if (length(fields) == 0) return(NULL)

  seq_ids <- as.integer(vapply(fields, `[`, character(1), c_seq))
  bfacs   <- as.numeric(vapply(fields, `[`, character(1), c_bfac))

  vec <- rep(NA_real_, max(seq_ids))
  vec[seq_ids] <- bfacs
  vec
}

#Accession is embedded in the file name: AF-<ACCESSION>-F1-model_v4.cif.gz
accession_of <- function(path) sub("^AF-([^-]+)-F1-model_v4\\.cif\\.gz$", "\\1", basename(path))

plddt_map <- list()
n <- length(cif_files)
for (k in seq_along(cif_files)) {
  acc <- accession_of(cif_files[k])
  vec <- tryCatch(parse_plddt(cif_files[k]), error = function(e) NULL)
  if (!is.null(vec)) plddt_map[[acc]] <- vec
  if (k %% 1000 == 0) message("  processed ", k, "/", n)
}

out_dir  <- file.path("maps", organism)
out_path <- file.path(out_dir, "plddt.rds")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

saveRDS(plddt_map, out_path, compress = "xz")
message("Wrote ", length(plddt_map), " proteins -> ", out_path)
