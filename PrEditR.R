#!/usr/bin/env Rscript

source("functions/loadFunctions.R")

loadFunctions()

# =====================================================================================================================
# Worker Function outside of runPrEditR to prevent large objects loaded in runPrEditR from being passed to each worker
# =====================================================================================================================

worker_fun <- function(query_num, gene_symbol, ensembl_id, uniprot_id, isoforms, target_aa,
                       target_position, editor, edit_type, organism, genome, 
                       txdb, editors_path, n_mismatches, n_max_alignments, flanking5, flanking3, 
                       session_tmp, debug, progressor) {

  dump_directory <- file.path(session_tmp, paste0("row_", query_num))
  if (debug) {
    dir.create(dump_directory, recursive = TRUE)
    options("tryCatchLog.write.error.dump.file" = TRUE,
            "tryCatchLog.write.error.dump.folder" = dump_directory)
  }
  
  tryCatchLog::tryCatchLog({
    
    local_genome <- getNamespace(genome)[[genome]]
    
    loadEditors(editors_path, editor)
    
    processed_res <- process_row(
      query_num, gene_symbol, ensembl_id, uniprot_id, isoforms, target_aa, target_position, editor, edit_type, organism, 
      genome = local_genome, 
      txdb = txdb,
      n_mismatches, n_max_alignments, flanking5, flanking3, session_tmp
    )
    
    if (!is.null(progressor)) progressor(message = "")
    if (!debug) unlink(dump_directory, recursive = TRUE)
    
    rm(local_genome)

    
    return(processed_res)
    
  }, error = function(e) {
    ParallelLogger::logError(paste0("Worker ", query_num, ": Error: ", e))
    error_res <- generateErrorOutput(query_num, FALSE, n_mismatches, gene_symbol, ensembl_id)
    if (!is.null(progressor)) progressor(message = "")
    
    rm(local_genome)

    
    return(error_res)
  })
}


# ===================================================================
# Main Process and Logging Setup
# ===================================================================
runPrEditR <- function(
    input_file,
    job_name,
    editors_path,
    output_path,
    organism,
    indexed_genome,
    n_mismatches,
    n_max_alignments,
    flanking5,
    flanking3,
    threads,
    shiny,
    off_targets,
    non_editing_controls,
    tmp,
    debug = FALSE,
    progressor = NULL){
  
  gc()
  loadSetupLibraries()
  
  if (shiny){
    # Recursive futures are now enabled globally in server.R
  }
  
  # Temporary directory setup
  if (shiny){
    session_tmp <- tmp # Comes with the unique session token
  } else {
    timest <- format(Sys.time(), "%Y%m%d-%H%M%S")
    random_str <- paste0(sample(c(0:9, letters), 6, replace = TRUE), collapse = "")
    session_token <- paste0(timest, "_", random_str)
    session_tmp <- normalizePath(file.path(tmp, paste0("preditr_", session_token)), mustWork = FALSE)
  }
  
  # --- 1. SAFE ENVIRONMENT VARIABLE SCOPING ---
  # Save the current TMPDIR so we can restore it when this function exits.
  # This prevents one user's temp dir from becoming the default for everyone else.
  old_tmpdir <- Sys.getenv("TMPDIR", unset = NA)
  
  # Set the TMPDIR for this specific run
  Sys.setenv(TMPDIR = session_tmp) 
  
  # Ensure restoration happens no matter how the function exits (success or error)
  on.exit({
    if (is.na(old_tmpdir)) {
      Sys.unsetenv("TMPDIR")
    } else {
      Sys.setenv(TMPDIR = old_tmpdir)
    }
  }, add = TRUE)
  
  # Create temporary directory
  dir.create(session_tmp, recursive = TRUE, showWarnings = FALSE)
  
  # Logging
  ParallelLogger::addDefaultFileLogger(file.path(session_tmp, paste0(job_name, ".log")))
  if (debug) {
    options("tryCatchLog.write.error.dump.file" = TRUE) 
  }
  
  # --- START JOB ---
  # Log app version
  app_info <- yaml::read_yaml("app_info.yaml")
  app <- app_info$app
  header <- paste0("========================== ", app$name, " v", app$version, " ==========================")
  ParallelLogger::logInfo(header)
  
  ParallelLogger::logInfo(paste0(
    paste0(rep(" ", ceiling(nchar(header)/3 - 3)), collapse = ""),
    "Last updated on ", app$last_updated
  ))
  
  ParallelLogger::logInfo(rep("=", nchar(header)))
  ParallelLogger::logInfo(paste0("Starting job: ", job_name))
  
  ParallelLogger::logInfo(paste0("Temporary directory created at ", session_tmp, "\n"))
  
  #Verify arguments meet the requirements before starting
  ParallelLogger::logInfo("Checking input requirements...")
  args_exit_code <- argsChecker(input_file, job_name, editors_path, output_path, organism, tmp,
                                off_targets, indexed_genome, n_mismatches)
  
  if (args_exit_code == 1){
    # Note: In Shiny mode, we rely on the global plan, so we don't stop the cluster here.
    # Cleanup of loggers is handled by on.exit or specific cleanup calls.
    if (!shiny) ParallelLogger::clearLoggers()
    return(1)
  }
  
  ParallelLogger::logInfo("Input meets the requirements.")
  
  # Resource validation
  if (threads > max(1, parallel::detectCores())) {
    ParallelLogger::logFatal(paste0("Threads (", threads, ") > available cores (", max(1, parallel::detectCores()), ").", "PrEditR caps usage at n-2 cores on HPCs."))
    if (!shiny) ParallelLogger::clearLoggers()
    return(1)
  }
  
  # ===================================================================
  # Input Data
  # ===================================================================
  ParallelLogger::logInfo(paste("Loading input table from:", input_file))
  if (!file.exists(input_file)) {
    ParallelLogger::logFatal(paste("Input file does not exist:", input_file))
    if (!shiny) ParallelLogger::clearLoggers()
    return(1)
  }
  df <- read.csv(input_file, colClasses = "character", blank.lines.skip = TRUE)
  df[] <- lapply(df, function(x) if (is.character(x)) trimws(x) else x) 
  df <- df[rowSums(df != "" & !is.na(df)) > 0, ] 
  df <- unique(df)
  df$query_num <- 1:nrow(df)

  
  #organism_data <- loadOrganismData(organism)
  
  #Map UNIPROT IDs to Ensembl IDs and Ensembl IDs to UNIPROT IDs
  trimmed_ensembl_ids <- trimEnsembl(as.character(df$ensembl_id))
  uniprot2ensembl_ids <- as.character(df$uniprot_id)
  ensembl2uniprot_ids <- trimmed_ensembl_ids 
  
  mapped_ensembl_ids <- mapUniprot2Ensembl(organism, uniprot2ensembl_ids)
  mapped_uniprot_ids <- mapEnsembl2Uniprot(organism, ensembl2uniprot_ids)
  
  df$ensembl_id_mapped <- mapped_ensembl_ids
  df$uniprot_id_mapped <- mapped_uniprot_ids
  
  merged_mapped_ensembl_ids <- ifelse(
    !is.na(df$ensembl_id) & nzchar(df$ensembl_id),
    df$ensembl_id,
    df$ensembl_id_mapped
  )
  
  merged_mapped_uniprot_ids <- ifelse(
    !is.na(df$uniprot_id) & nzchar(df$uniprot_id),
    df$uniprot_id,
    df$uniprot_id_mapped
  )
  
  df$ensembl_id <- merged_mapped_ensembl_ids
  df$uniprot_id <- merged_mapped_uniprot_ids
  df$ensembl_id_mapped <- NULL
  df$uniprot_id_mapped <- NULL
  
  #Flag those that are known to have multiple isoforms
  df$isoforms <- flagIsoforms(organism, df$uniprot_id)
  
  #Genome:
  if (organism == "human") {
    genome_pkg <- "BSgenome.Hsapiens.UCSC.hg38"
    #library(BSgenome.Hsapiens.UCSC.hg38)
    utils::data("txdb_human", package="crisprDesignData", envir = environment())
    #flat_granges <- unlist(txdb_human) #Will be filtered down later
    
    small_txdb <- list(
      exons = txdb_human$exons[txdb_human$exons$tx_id %in% unique(merged_mapped_ensembl_ids)],
      cds = txdb_human$cds[txdb_human$cds$tx_id %in% unique(merged_mapped_ensembl_ids)],
      transcripts = txdb_human$transcripts[txdb_human$transcripts$tx_id %in% unique(merged_mapped_ensembl_ids)],
      fiveUTRs = txdb_human$fiveUTRs[txdb_human$fiveUTRs$tx_id %in% unique(merged_mapped_ensembl_ids)],
      threeUTRs = txdb_human$threeUTRs[txdb_human$threeUTRs$tx_id %in% unique(merged_mapped_ensembl_ids)],
      introns = txdb_human$introns[txdb_human$introns$tx_id %in% unique(merged_mapped_ensembl_ids)],
      tss = txdb_human$tss[txdb_human$tss$tx_id %in% unique(merged_mapped_ensembl_ids)]
    )
    
    small_txdb <- GenomicRanges::GRangesList(small_txdb, compress=TRUE)
    rm(txdb_human, envir = environment())
  } else {
    genome_pkg <- "BSgenome.Mmusculus.UCSC.mm10"
    #library(BSgenome.Mmusculus.UCSC.mm10)
    utils::data("txdb_mouse", package="crisprDesignData", envir = environment())
    #flat_granges <- unlist(txdb_mouse) #Will be filtered down later
    
    small_txdb <- list(
      exons = txdb_mouse$exons[txdb_mouse$exons$tx_id %in% unique(merged_mapped_ensembl_ids)],
      cds = txdb_mouse$cds[txdb_mouse$cds$tx_id %in% unique(merged_mapped_ensembl_ids)],
      transcripts = txdb_mouse$transcripts[txdb_mouse$transcripts$tx_id %in% unique(merged_mapped_ensembl_ids)],
      fiveUTRs = txdb_mouse$fiveUTRs[txdb_mouse$fiveUTRs$tx_id %in% unique(merged_mapped_ensembl_ids)],
      threeUTRs = txdb_mouse$threeUTRs[txdb_mouse$threeUTRs$tx_id %in% unique(merged_mapped_ensembl_ids)],
      introns = txdb_mouse$introns[txdb_mouse$introns$tx_id %in% unique(merged_mapped_ensembl_ids)],
      tss = txdb_mouse$tss[txdb_mouse$tss$tx_id %in% unique(merged_mapped_ensembl_ids)]
    )
    
    small_txdb <- GenomicRanges::GRangesList(small_txdb, compress=TRUE)
    rm(txdb_mouse, envir = environment())
  }
  
  rm(trimmed_ensembl_ids, uniprot2ensembl_ids, ensembl2uniprot_ids, 
     mapped_ensembl_ids, mapped_uniprot_ids, merged_mapped_ensembl_ids, 
     merged_mapped_uniprot_ids)
  gc()
  
  #genome_dir <- utils::system.file("extdata", package = genome_pkg)
  #twobit_files <- list.files(genome_dir, pattern = "\\.2bit$", full.names = TRUE)
  #twobit_path <- utils::system.file("seqs", "single_sequences.2bit", package = genome_pkg)
  
  ParallelLogger::logInfo("Organism-specific resources loaded.")
  
  # ===================================================================
  # Parallel Backend Configuration
  # ===================================================================
  
  hosted <- Sys.getenv("PREDITR_HOSTED", "FALSE") %in% c("TRUE", "true", "1")
  
  # --- 2. INHERITED PLAN STRATEGY ---
  if (shiny) {
    ParallelLogger::logInfo("Running in managed-host mode (Shiny). Inheriting global parallel plan.")
  } else {
    # CLI mode
    options(parallelly.fork.enable = TRUE) # For multisession
    options(parallelly.maxWorkers.localhost = Inf) #For multisession
    future::plan(strategy = "multicore", workers = threads)
    ParallelLogger::logInfo(paste0("Running on ", threads, " cores (multicore)."))
  }
  
  # ===================================================================
  # Parallel Execution
  # ===================================================================
  ParallelLogger::logInfo(paste0("Dispatching ", nrow(df), " tasks..."))
  
  export_globals <- c(
    
    "addNEC", "annotateEdits", "argsChecker", "calculatePAMRange", 
    "checkCodonLocations", "checkIDs", "cleanLog", "createEditor", 
    "findCodonLocus", "findGuides", "findLongestTrimmedMatch", 
    "findOffTargets", "findPotentialLocus", "findRegionsOfInterest", 
    "findRelativeTargetBasePosition", "flagGuides", "generateEditedCodons", 
    "generateErrorOutput", "generateOutput", "generatePartialOutput", 
    "generatePrettyTable", "generateWindowSequences", "getCodingSequences", 
    "getWindowSeqs2","isNEC", "loadEditors", "loadFunctions", "loadLibraries", 
    "loadOrganismData", "mapEnsembl2MGI", "mapEnsembl2Uniprot", 
    "mapUniprot2Ensembl", "parseArguments", "process_row", 
    "scoreGuides", "spansIntron", "summarizeEdits", "summaryPlots", 
    "trimEnsembl", "worker_fun", "progressor"
  )
  
  worker_packages <- c(process_pkgs, genome_pkg) #process_pkgs is globally created in loadLibraries.R
  
  for (pkg in worker_packages) {
    requireNamespace(pkg, quietly = TRUE)
  }
  
  gc(full = TRUE) #Important to run right before future_pmap() because the workers might inherit objects that they don't need from the parent environment
  
  results <- furrr::future_pmap(
    .l = list(df$query_num, df$gene_symbol, df$ensembl_id, df$uniprot_id, df$isoforms,
              df$target_aa, df$target_position, df$editor, df$edit_type),
    .f = worker_fun,
    organism = organism,
    genome = genome_pkg,
    txdb = small_txdb,
    editors_path = editors_path,
    n_mismatches = n_mismatches,
    n_max_alignments = n_max_alignments,
    flanking5 = flanking5,
    flanking3 = flanking3,
    session_tmp = session_tmp,
    debug = debug,
    progressor = progressor,
    .options = furrr::furrr_options(
      globals = export_globals,
      packages = worker_packages,
      seed = TRUE
    )
  )
  
  
  ParallelLogger::logInfo("All tasks have completed.")
  future::plan(future::sequential) #Kill the parallel infrastructure to reclaim RAM
  
  # ===================================================================
  # Post-Processing
  # ===================================================================
  loadPostLibraries()
  
  if (debug) {
    final_dump_dir <- file.path(session_tmp, "end")
    dir.create(final_dump_dir, recursive = TRUE)
    options("tryCatchLog.write.error.dump.folder" = final_dump_dir)  
  }
  tryCatchLog::tryCatchLog({
    if (off_targets) {
      ParallelLogger::logInfo("Performing off-target searches...")
      if (!is.null(progressor)) {
        progressor(message = "Performing off-target searches...", steps = as.integer(Sys.getenv("PREDITR_STEPS"))-1)
      }
      if (shiny) {
        suppressMessages(
          organism_data <- loadOrganismData(organism)
        )
        genome <- organism_data$genome
        txdb   <- organism_data$txdb
      }
      offtargets_df <- findOffTargets(results, genome, indexed_genome,
                                      n_mismatches, n_max_alignments, txdb)
      ParallelLogger::logInfo("Off-target search complete.")
    } else {
      ParallelLogger::logInfo("Skipping off-target searches.")
      offtargets_df <- data.frame()
    }
    
    ParallelLogger::logInfo("Preparing final output files...")
    
    if (shiny && !is.null(progressor)){
      progressor(message = "Wrapping up...", steps = as.integer(Sys.getenv("PREDITR_STEPS")))
    }
    
    results_df <- generateOutput(df, job_name, output_path, results, offtargets_df, off_targets,
                                 organism, editors_path, non_editing_controls, flanking5, flanking3,
                                 genome, indexed_genome, n_mismatches, n_max_alignments, txdb)
    
    if (shiny){
      ParallelLogger::logInfo("Preparing summary plot and interactive table...")
      summaryPlots(results_df, job_name, output_path)
      generatePrettyTable(results_df, organism, job_name, output_path)
    }
    
    ParallelLogger::logInfo(paste0("Results file created at: ", file.path(output_path, paste0(job_name, "_results.csv"))))
    ParallelLogger::logInfo("Finalizing log...")
    ParallelLogger::logInfo(paste0("Log file created at: ", file.path(output_path, paste0(job_name, ".log"))))
    ParallelLogger::logInfo(paste("Job", job_name, "finished successfully."))
    
    # --- 3. CONDITIONAL CLEANUP ---
    # If not Shiny, we clean up the session folder and loggers.
    # If Shiny, we LEAVE loggers/files because the user still needs to download them.
    
    if (!shiny){ 
      # CLI Cleanup
      cleanLog(session_tmp, job_name, output_path)
      
      if (dir.exists(file.path(session_tmp))) {
        unlink(file.path(session_tmp), recursive = TRUE)
      }
      
      try(ParallelLogger::clearLoggers(), silent = TRUE)
      try(closeAllConnections(), silent = TRUE)
      try(future::ClusterRegistry("stop"), silent = TRUE)
    } else {
      # Shiny Cleanup: 
      # Just clean the log formatting, but don't delete files or kill the cluster.
      cleanLog(session_tmp, job_name, output_path)
    }
    
    gc(full = TRUE)
    
    return(0)
    
  }, logged.conditions = NULL,
  error = function(e){
    ParallelLogger::logError(e$message)
    
    # Error Cleanup
    if (!shiny){
      try(ParallelLogger::clearLoggers(), silent = TRUE)
      try(closeAllConnections(), silent = TRUE)
      try(future::ClusterRegistry("stop"), silent = TRUE)
    }
    
    gc(full = TRUE)
    
    return(1)
  })
  
}
# ===================================================================
# CLI Entry Point
# ===================================================================
if (identical(Sys.getenv("PREDITR_MODE"), "CLI")) {
  source("functions/loadFunctions.R")
  loadFunctions()
  
  if (!requireNamespace("argparser", quietly = TRUE)) stop("argparser required")
  
  args <- parseArguments()
  
  exit_code <- runPrEditR(
    input_file     = args$input,
    job_name       = args$job_name,
    editors_path   = args$editors,
    output_path    = args$output_path,
    organism       = args$organism,
    indexed_genome = args$indexed_genome,
    n_mismatches   = as.integer(args$n_mismatches),
    n_max_alignments = as.integer(args$n_max_alignments),
    flanking5      = args$flanking5,
    flanking3      = args$flanking3,
    threads        = as.integer(args$threads),
    shiny          = as.logical(args$shiny),
    off_targets    = as.logical(args$off_targets),
    non_editing_controls = as.logical(args$non_editing_controls),
    tmp            = args$tmp,
    debug          = (Sys.getenv("PREDITR_DEBUG") == "TRUE")
  )
  
  quit(status = exit_code)
}