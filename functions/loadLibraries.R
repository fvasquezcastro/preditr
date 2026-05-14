# --- Helper to check packages without attaching them ---
check_availability <- function(pkgs) {
  missing <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
  if (length(missing) > 0) {
    stop(paste("The following required packages are not installed:", 
               paste(missing, collapse = ", ")))
  }
}

# 1. Setup Libraries: Required for the parent to manage the job
# Note: We still load 'future' and 'ParallelLogger' in the parent 
# because they manage the orchestration and logging.
loadSetupLibraries <- function() {
  suppressPackageStartupMessages({
    parent_essentials <- c("future", "furrr", "parallel", "progressr", 
                           "argparser", "tryCatchLog", "ParallelLogger", "yaml")
    
    for (lib in parent_essentials) {
      library(lib, character.only = TRUE)
    }
  })
}

# 2. Worker Packages: Character vector to be passed to furrr_options
# We do NOT use library() here. This keeps the parent RAM clean.
process_pkgs <- c(
  "crisprBase", 
  "crisprDesign",
  "crisprDesignData", 
  "GenomicFeatures",
  "Biostrings", 
  "tryCatchLog"
)

# 3. Core Libraries: Validation only
# Call this in the parent to ensure workers won't fail later
loadCoreLibraries <- function() {
  check_availability(process_pkgs)
  # No library() calls here!
}

# 4. Post-Processing: Only called AFTER workers finish
loadPostLibraries <- function() {
  suppressPackageStartupMessages({
    post_pkgs <- c("purrr", "stringr", "gtools", "ggplot2")
    for (lib in post_pkgs) {
      library(lib, character.only = TRUE)
    }
  })
}