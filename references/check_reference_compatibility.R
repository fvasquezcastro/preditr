#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 1) {
  stop("Usage: check_reference_compatibility.R <reference_dir> [maps_root]", call. = FALSE)
}

reference_dir <- normalizePath(args[[1]], mustWork = FALSE)
maps_root <- if (length(args) >= 2) normalizePath(args[[2]], mustWork = FALSE) else file.path(reference_dir, "maps")

errors <- character()
notes <- character()

add_error <- function(...) {
  errors <<- c(errors, paste0(...))
}

add_note <- function(...) {
  notes <<- c(notes, paste0(...))
}

assert_file <- function(path, label) {
  if (!file.exists(path)) {
    add_error(label, " not found: ", path)
    return(FALSE)
  }
  TRUE
}

assert_dir <- function(path, label) {
  if (!dir.exists(path)) {
    add_error(label, " not found: ", path)
    return(FALSE)
  }
  TRUE
}

manifest_path <- file.path(reference_dir, "preditr_reference.json")
invisible(assert_dir(reference_dir, "Reference directory"))
invisible(assert_file(manifest_path, "Manifest"))

rlib_guess <- file.path(reference_dir, "rlib")
if (dir.exists(rlib_guess)) {
  .libPaths(c(rlib_guess, .libPaths()))
}

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  add_error("Package jsonlite is required by the reference loader but is not installed.")
}

manifest <- NULL
if (length(errors) == 0) {
  manifest <- tryCatch(
    jsonlite::fromJSON(manifest_path),
    error = function(e) {
      add_error("Manifest is not valid JSON: ", conditionMessage(e))
      NULL
    }
  )
}

required_fields <- c(
  "schema_version",
  "organism_id",
  "organism_label",
  "genome_build",
  "reference_kind",
  "bioconductor_version",
  "r_library_path",
  "genome_package",
  "annotation_package",
  "annotation_object",
  "annotation_loader",
  "packages"
)

if (!is.null(manifest)) {
  missing_fields <- setdiff(required_fields, names(manifest))
  if (length(missing_fields) > 0) {
    add_error("Manifest is missing required field(s): ", paste(missing_fields, collapse = ", "))
  }
  if (identical(manifest$annotation_loader, "rds") && !"annotation_path" %in% names(manifest)) {
    add_error("Manifest is missing annotation_path for annotation_loader=rds.")
  }
}

if (length(errors) > 0) {
  cat(paste0("ERROR: ", errors, "\n"), sep = "")
  quit(status = 1)
}

organism_id <- manifest$organism_id
reference_rlib <- file.path(reference_dir, manifest$r_library_path)

invisible(assert_dir(reference_rlib, "Reference R library"))
.libPaths(c(reference_rlib, .libPaths()))

allowed_current_organisms <- c("human", "mouse")
allow_non_builtin <- Sys.getenv("PREDITR_ALLOW_NON_BUILTIN_REFERENCE", "FALSE") %in% c("TRUE", "true", "1")
if (!allow_non_builtin && !organism_id %in% allowed_current_organisms) {
  add_error(
    "Current PrEditR dispatch only supports organism_id values human and mouse. ",
    "Refactor PrEditR.R, loadOrganismData.R, server.R, ui.R, and generatePrettyTable.R before this reference can work: ",
    organism_id
  )
}

if (!manifest$annotation_loader %in% c("data", "package-object", "rds")) {
  add_error("annotation_loader must be data, package-object, or rds, got: ", manifest$annotation_loader)
}

for (pkg in manifest$packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    add_error("Listed package is not loadable from reference image: ", pkg)
  }
}

for (pkg in c(manifest$genome_package, manifest$annotation_package)) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    add_error("Required package is not loadable: ", pkg)
  }
}

required_runtime_packages <- c("BiocGenerics", "Biostrings", "GenomicRanges", "GenomeInfoDb", "IRanges", "S4Vectors")
for (pkg in required_runtime_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    add_error("Required runtime package is not loadable: ", pkg)
  }
}

if (length(errors) > 0) {
  cat(paste0("ERROR: ", errors, "\n"), sep = "")
  quit(status = 1)
}

genome_obj <- tryCatch(
  getNamespace(manifest$genome_package)[[manifest$genome_package]],
  error = function(e) {
    add_error(
      "Genome package does not expose an object named exactly like the package. ",
      "PrEditR workers currently require getNamespace(genome_package)[[genome_package]]: ",
      conditionMessage(e)
    )
    NULL
  }
)

if (!is.null(genome_obj)) {
  if (!inherits(genome_obj, "BSgenome")) {
    add_error("Genome object is not BSgenome-compatible. Class found: ", paste(class(genome_obj), collapse = ", "))
  }

  genome_seqnames <- tryCatch(
    GenomeInfoDb::seqnames(genome_obj),
    error = function(e) {
      add_error("Could not retrieve genome seqnames: ", conditionMessage(e))
      character()
    }
  )

  genome_seqlengths <- tryCatch(
    GenomeInfoDb::seqlengths(genome_obj),
    error = function(e) {
      add_error("Could not retrieve genome seqlengths: ", conditionMessage(e))
      NULL
    }
  )

  if (length(genome_seqnames) == 0) {
    add_error("Genome object has no seqnames.")
  }

  test_seqname <- NA_character_
  if (!is.null(genome_seqlengths) && length(genome_seqlengths) > 0) {
    usable <- names(genome_seqlengths)[!is.na(genome_seqlengths) & genome_seqlengths >= 50]
    if (length(usable) > 0) {
      test_seqname <- usable[[1]]
    }
  }

  if (!is.na(test_seqname)) {
    test_range <- GenomicRanges::GRanges(
      seqnames = test_seqname,
      ranges = IRanges::IRanges(start = 1, width = 50)
    )
    seq_result <- tryCatch(
      Biostrings::getSeq(genome_obj, test_range),
      error = function(e) {
        add_error("Biostrings::getSeq failed on genome object: ", conditionMessage(e))
        NULL
      }
    )
    if (!is.null(seq_result) && length(seq_result) != 1) {
      add_error("Biostrings::getSeq returned unexpected length for genome object.")
    }
  } else {
    add_error("No genome sequence with known length >= 50 was available for getSeq validation.")
  }
}

load_annotation_object <- function(manifest) {
  if (identical(manifest$annotation_loader, "data")) {
    env <- new.env(parent = emptyenv())
    utils::data(list = manifest$annotation_object, package = manifest$annotation_package, envir = env)
    if (!exists(manifest$annotation_object, envir = env, inherits = FALSE)) {
      stop("utils::data did not load object: ", manifest$annotation_object)
    }
    return(env[[manifest$annotation_object]])
  }

  if (identical(manifest$annotation_loader, "package-object")) {
    return(getExportedValue(manifest$annotation_package, manifest$annotation_object))
  }

  if (identical(manifest$annotation_loader, "rds")) {
    annotation_path <- file.path(reference_dir, manifest$annotation_path)
    if (!file.exists(annotation_path)) {
      stop("annotation_path does not exist: ", annotation_path)
    }
    return(readRDS(annotation_path))
  }

  stop("Unsupported annotation_loader: ", manifest$annotation_loader)
}

txdb <- tryCatch(
  load_annotation_object(manifest),
  error = function(e) {
    add_error("Could not load annotation object: ", conditionMessage(e))
    NULL
  }
)

required_txdb_features <- c("exons", "cds", "transcripts", "fiveUTRs", "threeUTRs", "introns", "tss")

if (!is.null(txdb)) {
  if (!inherits(txdb, "GRangesList")) {
    add_error(
      "Annotation object is not a GRangesList. Current PrEditR expects a crisprDesignData-style ",
      "GRangesList with named features, not a raw TxDb object. Class found: ",
      paste(class(txdb), collapse = ", ")
    )
  }

  feature_names <- names(txdb)
  missing_features <- setdiff(required_txdb_features, feature_names)
  if (length(missing_features) > 0) {
    add_error("Annotation object is missing required feature(s): ", paste(missing_features, collapse = ", "))
  }

  for (feature in intersect(required_txdb_features, feature_names)) {
    feature_obj <- txdb[[feature]]
    if (!inherits(feature_obj, "GRanges")) {
      add_error("Annotation feature is not a GRanges object: ", feature)
      next
    }
    if (!"tx_id" %in% names(S4Vectors::mcols(feature_obj))) {
      add_error("Annotation feature is missing tx_id metadata column: ", feature)
    }
  }

  if ("cds" %in% feature_names && inherits(txdb[["cds"]], "GRanges")) {
    cds <- txdb[["cds"]]
    cds_mcols <- names(S4Vectors::mcols(cds))
    if (!"gene_symbol" %in% cds_mcols) {
      add_error("Annotation cds feature is missing gene_symbol metadata column.")
    }
    if (length(cds) == 0) {
      add_error("Annotation cds feature is empty.")
    }

    if (length(errors) == 0) {
      tx_ids <- unique(cds$tx_id)
      tx_ids <- tx_ids[!is.na(tx_ids) & nzchar(tx_ids)]
      if (length(tx_ids) == 0) {
        add_error("Annotation cds feature has no usable tx_id values.")
      } else {
        first_tx <- tx_ids[[1]]
        first_cds <- cds[cds$tx_id == first_tx]
        cds_seqnames <- unique(as.character(GenomeInfoDb::seqnames(first_cds)))
        genome_seqnames <- GenomeInfoDb::seqnames(genome_obj)
        missing_seqnames <- setdiff(cds_seqnames, genome_seqnames)
        if (length(missing_seqnames) > 0) {
          add_error(
            "CDS seqnames do not all exist in the genome. Missing: ",
            paste(utils::head(missing_seqnames, 10), collapse = ", ")
          )
        } else {
          cds_seq <- tryCatch(
            Biostrings::getSeq(genome_obj, first_cds),
            error = function(e) {
              add_error("Biostrings::getSeq failed for annotation CDS ranges: ", conditionMessage(e))
              NULL
            }
          )

          if (!is.null(cds_seq)) {
            cds_width <- sum(BiocGenerics::width(cds_seq))
            if (cds_width < 3) {
              add_error("First test transcript has CDS width < 3.")
            } else {
              dna <- Biostrings::DNAString(paste0(as.character(cds_seq), collapse = ""))
              tryCatch(
                Biostrings::translate(dna, genetic.code = Biostrings::GENETIC_CODE, no.init.codon = FALSE),
                error = function(e) {
                  add_error("Biostrings::translate failed for first test transcript CDS: ", conditionMessage(e))
                }
              )
            }
          }
        }
      }
    }
  }
}

organism_maps_dir <- file.path(maps_root, organism_id)
if (!assert_dir(organism_maps_dir, "Organism map directory")) {
  add_note("Current workflow reads maps from maps/<organism>; reference images must be paired with these map assets.")
} else {
  required_map_files <- c("uniprot_to_ensembl.rds", "ensembl_to_uniprot.rds", "has_isoforms.rds")
  for (map_file in required_map_files) {
    map_path <- file.path(organism_maps_dir, map_file)
    if (assert_file(map_path, paste0("Map file ", map_file))) {
      map_obj <- tryCatch(
        readRDS(map_path),
        error = function(e) {
          add_error("Could not read map file ", map_file, ": ", conditionMessage(e))
          NULL
        }
      )
      if (!is.null(map_obj) && !is.environment(map_obj)) {
        add_error("Map file does not contain an environment as expected by current workflow: ", map_file)
      }
    }
  }
}

if (!organism_id %in% c("human", "mouse")) {
  add_note(
    "generatePrettyTable() currently treats every non-human organism as mouse and calls mapEnsembl2MGI(). ",
    "That must be refactored before non-human/non-mouse Shiny output can work."
  )
}

if (length(notes) > 0) {
  cat(paste0("NOTE: ", notes, "\n"), sep = "")
}

if (length(errors) > 0) {
  cat(paste0("ERROR: ", errors, "\n"), sep = "")
  quit(status = 1)
}

cat("Reference compatibility checks passed for organism: ", organism_id, "\n", sep = "")
quit(status = 0)
