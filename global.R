options(future.globals.maxSize = 1000 * 1024^2)  # 1 GB
options(progressr.enable = TRUE)
options(future.fork.enable = TRUE)

# Progress bar handling (still handled in Shiny via withProgressShiny + progressr)
progressr::handlers(global = TRUE)
progressr::handlers("shiny")

# Default file size limit (overridden below if hosted)
options(shiny.maxRequestSize = 500 * 1024^2)  # 500 MB

# --- ENVIRONMENT CONFIGURATION (HOSTED FLAGS) ---
hosted <- Sys.getenv("PREDITR_HOSTED", "FALSE") %in% c("TRUE", "true", "1")

# --- PATHS (apply to both hosted and local, e.g. Docker Compose deployments) ---
# Base directory for per-session output folders. Defaults to "tmp" (relative to the
# app working directory) to preserve the historical behavior; the Compose stack sets
# PREDITR_OUTPUTS_PATH=/outputs so results land on the mounted host volume.
outputs_path <- Sys.getenv("PREDITR_OUTPUTS_PATH", unset = "tmp")

# Base directory holding per-organism reference data (one subdirectory per organism,
# each with a preditr_reference.json), populated by the reference initializer images.
# Empty when unset; the Compose stack sets PREDITR_REFERENCES_PATH=/refs. NOTE: the
# app does not yet auto-discover/load organisms from this path (organism support is
# still the hardcoded human/mouse packages baked into the app image); this exposes the
# path for that upcoming reference-discovery layer. The reference images that
# populate this path are built in the separate preditr_ref repo.
references_path <- Sys.getenv("PREDITR_REFERENCES_PATH", unset = "")

# Initialize global variables
hosted_threads <- 2
max_input_rows <- 500
allow_off_targets <- FALSE
allow_non_editing <- FALSE
allow_off_targets_finetuning <- FALSE
hosted_indexed_genomes_path <- ""

if (hosted) {
  hosted_threads <- as.numeric(Sys.getenv("PREDITR_THREADS", unset = 2))
  max_input_rows <- as.numeric(Sys.getenv("PREDITR_INPUT_ROWS", unset = 500))
  max_file_size  <- as.numeric(Sys.getenv("PREDITR_FILE_SIZE", unset = 2))
  
  options(shiny.maxRequestSize = max_file_size * 1024^2)
  
  allow_off_targets <- Sys.getenv("PREDITR_OFF_TARGETS", "FALSE") %in% c("TRUE", "true", "1")
  allow_non_editing <- Sys.getenv("PREDITR_NON_EDITING", "FALSE") %in% c("TRUE", "true", "1")
  allow_off_targets_finetuning <- Sys.getenv("PREDITR_OFF_TARGETS_FINETUNING", "FALSE") %in% c("TRUE", "true", "1")
  
  if (allow_off_targets) {
    hosted_indexed_genomes_path <- file.path(Sys.getenv("PREDITR_INDEX_GENOMES_PATH"))
  }
}

