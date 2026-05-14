loadLibraries <- function(){
  
  # Suppress messages and warnings for the entire loading block
  suppressPackageStartupMessages(suppressWarnings({
    
    # --- Load All Required Libraries ---
    
    # Bioconductor Core
    library(crisprBase)
    library(crisprDesign)
    library(crisprDesignData)
    library(GenomicFeatures)
    library(Biostrings)
    
    # Alignment and Scoring
    library(Rbowtie)
    library(crisprBwa)
    library(crisprBowtie)
    library(crisprScore)
    
    # Parallel Processing & Async
    library(future)
    library(future.apply)
    library(furrr)
    library(parallel)
    library(progressr)
    #library(SharedObject)
    
    # Logging and Error Handling
    library(logger)
    library(tryCatchLog)
    library(ParallelLogger)
    
    # Data Manipulation & Utilities
    library(dplyr)
    library(purrr)
    library(stringr)
    library(gtools)
    library(fastmatch)
    
    # Scripting & Reporting
    library(argparser)
    library(tools)
    library(yaml)
    
    # Summary plots
    library(ggplot2)
  }))
  
}