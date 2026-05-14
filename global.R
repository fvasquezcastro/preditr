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

