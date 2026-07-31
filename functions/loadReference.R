# Reference resolver for the Docker reference-image model (branch `compose`).
#
# References are distributed as `fvasquezcastro/preditr-ref:<organism>-<genome>`
# images whose one-shot containers copy `/image-refs/<organism>` into a shared
# directory (default `/refs`, overridable via PREDITR_REFERENCES_PATH or an
# explicit path argument). Each organism directory contains a discovery manifest
# `preditr_reference.json`, the R library `rlib/`, the annotation object, and
# `maps/`. This module discovers and loads those references for BOTH the Shiny
# app and the CLI. It fully replaces the old hardcoded human/mouse loader; there
# is no baked-in genome/annotation fallback left in the image.
#
# The image-side loader embedded by references/build_reference_image.sh
# (reference_loader.R) MUST stay in sync with load_reference() below.

# Resolve the base directory that holds per-organism reference subdirectories.
# Precedence: explicit argument > PREDITR_REFERENCES_PATH > "/refs".
referencesBasePath <- function(path = NULL) {
  if (!is.null(path) && nzchar(path)) {
    return(path)
  }
  env_path <- Sys.getenv("PREDITR_REFERENCES_PATH", unset = "")
  if (nzchar(env_path)) {
    return(env_path)
  }
  "/refs"
}

# Read and lightly validate one organism manifest. Returns NULL (with a warning)
# for anything unreadable, so discovery never aborts on a single bad directory.
readReferenceManifest <- function(manifest_path) {
  if (!file.exists(manifest_path)) {
    return(NULL)
  }
  manifest <- tryCatch(
    jsonlite::fromJSON(manifest_path),
    error = function(e) {
      warning(sprintf("Could not parse reference manifest %s: %s", manifest_path, conditionMessage(e)))
      NULL
    }
  )
  if (is.null(manifest)) {
    return(NULL)
  }
  required <- c("organism_id", "genome_package", "annotation_package",
               "annotation_object", "annotation_loader")
  missing <- required[!required %in% names(manifest)]
  if (length(missing) > 0) {
    warning(sprintf("Reference manifest %s missing fields: %s",
                    manifest_path, paste(missing, collapse = ", ")))
    return(NULL)
  }
  manifest$reference_dir <- normalizePath(dirname(manifest_path), mustWork = FALSE)
  manifest
}

# Discover every usable organism reference under the base path. Returns a
# data.frame (one row per organism) used to populate the Shiny dropdown and the
# CLI `--list-organisms` output. Empty data.frame when nothing is installed.
discoverReferences <- function(path = NULL) {
  base <- referencesBasePath(path)
  empty <- data.frame(
    organism_id = character(0), organism_label = character(0),
    genome_build = character(0), bioconductor_version = character(0),
    reference_dir = character(0), stringsAsFactors = FALSE
  )
  if (!dir.exists(base)) {
    return(empty)
  }
  manifest_paths <- list.files(base, pattern = "^preditr_reference\\.json$",
                               recursive = TRUE, full.names = TRUE)
  if (length(manifest_paths) == 0) {
    return(empty)
  }
  rows <- lapply(manifest_paths, function(mp) {
    m <- readReferenceManifest(mp)
    if (is.null(m)) return(NULL)
    data.frame(
      organism_id = m$organism_id,
      organism_label = if (!is.null(m$organism_label)) m$organism_label else m$organism_id,
      genome_build = if (!is.null(m$genome_build)) m$genome_build else NA_character_,
      bioconductor_version = if (!is.null(m$bioconductor_version)) m$bioconductor_version else NA_character_,
      reference_dir = m$reference_dir,
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0) {
    return(empty)
  }
  do.call(rbind, rows)
}

# Resolve a SINGLE organism payload directory (the folder that directly contains
# preditr_reference.json) into the (organism, base) pair the rest of the pipeline
# expects. This backs the CLI --reference flag and the equivalent Singularity
# bind-mount workflow, where the user extracts one organism from a preditr-ref
# image and points PrEditR straight at it.
#
# Returns list(organism = <id from manifest>, references_path = <parent dir>).
# The downstream resolvers (loadReference / referenceMapsDir) key maps off
# <references_path>/<organism>/..., so the payload directory name MUST equal the
# manifest organism_id; we validate that and fail loudly otherwise.
resolveSinglePayload <- function(reference_dir) {
  reference_dir <- normalizePath(reference_dir, mustWork = FALSE)
  if (!dir.exists(reference_dir)) {
    stop(sprintf("--reference directory does not exist: %s", reference_dir))
  }
  manifest <- readReferenceManifest(file.path(reference_dir, "preditr_reference.json"))
  if (is.null(manifest)) {
    stop(sprintf(
      "No usable preditr_reference.json in --reference directory '%s'. Point --reference at the folder that directly contains the manifest.",
      reference_dir))
  }
  organism <- manifest$organism_id
  if (!identical(basename(reference_dir), organism)) {
    stop(sprintf(
      paste0("--reference directory name ('%s') must equal the organism id ('%s') from its manifest, ",
             "because reference maps are resolved as <parent>/%s/maps. Rename the directory to '%s', ",
             "or use --references_path with a base directory instead."),
      basename(reference_dir), organism, organism, organism))
  }
  list(organism = organism, references_path = dirname(reference_dir))
}

# Directory holding one organism's ID maps (ensembl_to_uniprot.rds, etc.).
# Prefers the reference-image location `<base>/<organism>/maps`; falls back to
# the legacy in-repo `maps/<organism>` so the app keeps working before the
# hard-cut removes baked-in maps. Used by the map* / flagIsoforms functions.
referenceMapsDir <- function(organism, path = NULL) {
  base <- referencesBasePath(path)
  ref_maps <- file.path(base, organism, "maps")
  if (dir.exists(ref_maps)) {
    return(ref_maps)
  }
  file.path("maps", organism)  # legacy transition fallback
}

# Guardrail: rlib packages are copied from the reference image into this R
# session, so the reference's Bioconductor version must match the app's. Fail
# loudly here rather than crash deep inside crisprDesign.
assertBiocCompatible <- function(manifest) {
  ref_bioc <- manifest$bioconductor_version
  if (is.null(ref_bioc) || is.na(ref_bioc) || !nzchar(ref_bioc)) {
    return(invisible(TRUE))  # older manifests without the field: skip check
  }
  app_bioc <- as.character(BiocManager::version())
  if (!identical(ref_bioc, app_bioc)) {
    stop(sprintf(
      paste0("Reference '%s' was built for Bioconductor %s but this PrEditR image ",
             "uses Bioconductor %s. Rebuild the reference image for Bioconductor %s ",
             "(or use a matching app image)."),
      manifest$organism_id, ref_bioc, app_bioc, app_bioc))
  }
  invisible(TRUE)
}

# Load a package the reference declares, failing with the REAL error. This used to
# be a bare `requireNamespace(pkg, quietly = TRUE)` whose return value was
# discarded, so a payload that copied incompletely — or an rlib whose compiled
# packages were built for another architecture — was swallowed here and only
# surfaced ~20 lines later as an opaque getExportedValue() failure.
loadReferencePackage <- function(pkg, role, manifest, rlib) {
  if (is.null(pkg) || !nzchar(pkg)) {
    stop(sprintf("Reference '%s' declares no %s package.",
                 manifest$organism_id, role), call. = FALSE)
  }
  err <- tryCatch({ loadNamespace(pkg); NULL }, error = function(e) conditionMessage(e))
  if (is.null(err)) {
    return(invisible(TRUE))
  }
  stop(sprintf(
    paste0("Reference '%s' needs its %s package '%s', which failed to load: %s\n",
           "  reference dir: %s\n",
           "  bundled rlib : %s\n",
           "  library paths: %s\n",
           "Check that the payload copied completely, and that any compiled packages ",
           "in its rlib match this machine's architecture."),
    manifest$organism_id, role, pkg, err,
    manifest$reference_dir,
    if (dir.exists(rlib)) rlib else paste0(rlib, " (absent)"),
    paste(.libPaths(), collapse = ", ")), call. = FALSE)
}

# Load one organism's reference:
# returns list(txdb = <GRangesList>, genome = <BSgenome>, maps_dir, manifest).
# `organism` matches manifest$organism_id (e.g. "human"); `path` overrides the
# base references directory (CLI --references_path / PREDITR_REFERENCES_PATH).
loadReference <- function(organism, path = NULL) {
  base <- referencesBasePath(path)
  refs <- discoverReferences(base)
  if (nrow(refs) == 0) {
    stop(sprintf(
      "No references found under '%s'. Sync a reference image (e.g. preditr-ref:%s-<genome>) first.",
      base, organism))
  }
  match_idx <- which(refs$organism_id == organism)
  if (length(match_idx) == 0) {
    stop(sprintf("Organism '%s' not installed. Available: %s",
                 organism, paste(refs$organism_id, collapse = ", ")))
  }
  reference_dir <- refs$reference_dir[match_idx[1]]
  manifest <- readReferenceManifest(file.path(reference_dir, "preditr_reference.json"))
  assertBiocCompatible(manifest)

  # Make the reference's bundled packages importable. APPEND rather than prepend:
  # a payload's rlib is the genome package plus its whole dependency closure, built
  # for one architecture. Prepending let those bundled copies of Biostrings,
  # S4Vectors, IRanges, ... shadow the app image's own — harmless when the arches
  # match, fatal when they don't (an amd64 reference on an arm64 app image). The
  # only package a reference genuinely adds is the BSgenome data package, and
  # appending resolves that just as well while leaving shared dependencies to the
  # app image. assertBiocCompatible() above already guards the version skew that
  # prepending was protecting against.
  rlib <- file.path(reference_dir, if (!is.null(manifest$r_library_path)) manifest$r_library_path else "rlib")
  if (dir.exists(rlib)) {
    .libPaths(c(.libPaths(), rlib))
  }

  # The genome package is always required (getExportedValue() below needs it). The
  # annotation package is only needed by the "data"/"package-object" loaders — an
  # "rds" reference reads a prebuilt file and often does not ship the package at
  # all (human declares crisprDesignData purely as provenance).
  loadReferencePackage(manifest$genome_package, "genome", manifest, rlib)
  if (!identical(manifest$annotation_loader, "rds")) {
    loadReferencePackage(manifest$annotation_package, "annotation", manifest, rlib)
  }

  # Annotation object: rds (preferred, normalized GRangesList) / data / package-object.
  loader <- manifest$annotation_loader
  if (identical(loader, "rds")) {
    txdb <- readRDS(file.path(reference_dir, manifest$annotation_path))
  } else if (identical(loader, "data")) {
    env <- new.env(parent = emptyenv())
    utils::data(list = manifest$annotation_object, package = manifest$annotation_package, envir = env)
    txdb <- env[[manifest$annotation_object]]
  } else if (identical(loader, "package-object")) {
    txdb <- getExportedValue(manifest$annotation_package, manifest$annotation_object)
  } else {
    stop(sprintf("Unsupported annotation_loader '%s' in reference '%s'.", loader, organism))
  }

  # BSgenome packages export the genome object under the package name.
  genome <- getExportedValue(manifest$genome_package, manifest$genome_package)

  maps_dir <- file.path(reference_dir, "maps")

  ParallelLogger::logInfo(sprintf("Loaded reference '%s' (%s) from %s",
                                  organism,
                                  if (!is.null(manifest$genome_build)) manifest$genome_build else "?",
                                  reference_dir))

  list(
    txdb = txdb,
    genome = genome,
    maps_dir = if (dir.exists(maps_dir)) maps_dir else NA_character_,
    manifest = manifest
  )
}
