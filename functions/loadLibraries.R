loadLibraries <- function(){
  
  pkgs <- c(
    "crisprBase", "crisprDesign", "crisprDesignData", "GenomicFeatures",
    "Biostrings", "argparser", "purrr", "future", "future.apply",
    "Rbowtie", "crisprBwa", "crisprBowtie", "crisprScore", "parallel",
    "dplyr", "gtools", "logger", "stringr", "tools", "yaml",
    "fastmatch", "furrr", "progressr", "tryCatchLog", "ParallelLogger"
  )
  
  invisible(lapply(pkgs, function(pkg) {
    suppressPackageStartupMessages(suppressWarnings(library(pkg, character.only = TRUE)))
  }))
  
}