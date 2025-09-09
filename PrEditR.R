#!/usr/bin/env Rscript


# ===================================================================
# Script Setup and Library Loading
# ===================================================================
#setwd("/home/") #-> Necessary for the script inside the container
source("functions/loadFunctions.R")
loadFunctions()
loadLibraries()

# ===================================================================
# Argument Parsing and Configuration
# ===================================================================

args <- parseArguments()

input_file <- args$input
job_name <- args$job_name
editors_path <- args$editors
output_path <- args$output
organism <- args$organism
indexed_genome <- args$indexed_genome
n_mismatches <- as.integer(args$n_mismatches)
n_max_alignments <- as.integer(args$n_max_alignments)
flanking5 <- args$flanking5
flanking3 <- args$flanking3
threads <- as.integer(args$threads)
shiny <- as.logical(args$shiny)
off_targets <- as.logical(args$off_targets)
non_targeting_controls <- as.logical(args$non_targeting_controls)
tmp_folder <- args$tmp_folder
debug <- ifelse(Sys.getenv("PREDITR_DEBUG") == "TRUE", TRUE, FALSE)

# ===================================================================
# Main Process and Logging Setup
# ===================================================================

#Log app version
app_info <- yaml::read_yaml("app_info.yaml")
app <- app_info$app
logInfo(paste("========", app$name, "v", app$version, "========"))
logInfo(paste("=== Last updated on", app$last_updated, "==="))
logInfo("===========================================")
logInfo(paste("Starting job:", job_name))

# Clean up and create the main log directory
timest <- format(Sys.time(), "%Y%m%d-%H%M%S")
random_str <- paste0(sample(c(0:9, letters), 6, replace = TRUE), collapse = "")
preditr_temp <- paste0("preditr_temp", "_", timest, "_", random_str) #Unique temp folder to avoid collisions between concurrent jobs

if (dir.exists(file.path(tmp_folder, preditr_temp))) {
  unlink(file.path(tmp_folder, preditr_temp), recursive = TRUE)
}

cat(paste0("Temporary directory created at ", preditr_temp))
dir.create(file.path(tmp_folder, preditr_temp), recursive = TRUE)

# Configure ParallelLogger to write to a central, parallel-safe log file.
ParallelLogger::addDefaultFileLogger(file.path(tmp_folder, preditr_temp, paste0(job_name, ".log")))

if (debug){
  # Configure tryCatchLog for post-mortem debugging.
  # On error, it will save the worker's environment to an.Rda file. The specific folder is defined in the worker function
  options(
    "tryCatchLog.write.error.dump.file" = TRUE
  ) 
}


# Validate available resources
if (threads > detectCores()) {
  logFatal(paste0("The number of threads (", threads, ") is greater than the number of cores available (", detectCores(), ")."))
  stop(paste0("The number of threads is greater than the number of cores available: ", detectCores()))
}


# ===================================================================
# Input Data Loading
# ===================================================================
logInfo(paste("Loading input table from:", input_file))

if (!file.exists(input_file)) {
  logFatal(paste("Input file does not exist:", input_file))
  stop("Input file not found.")
}

df <- read.csv(input_file, colClasses = "character", blank.lines.skip	= TRUE)
df <- df %>% mutate(query_num = row_number())

# ===================================================================
# Parallel Backend Configuration
# ===================================================================
progress_file <- NULL

if (shiny){
  
  future::plan(strategy = "multisession", workers = threads)
  logInfo("Detecting resources available")
  logInfo(paste0("Running on ", threads, " cores (out of ", detectCores(), " available) in multisession mode."))
  
  # Create new progress file
  progress_file <- file.path("shiny_tmp", "progress.txt")
  
  # Clean up anything from previous runs
  if (file.exists(progress_file)){
    file.remove(progress_file)
  }
  
} else {
  
  future::plan(strategy = "multicore", workers = threads)
  logInfo("Detecting resources available")
  logInfo(paste0("Running on ", threads, " cores (out of ", detectCores(), " available) in multicore mode. (Not supported on Windows)"))
  
  logInfo("Loading organism data")

  suppressMessages(
    organism_data <- loadOrganismData(organism)
  )
  
  
  genome <- organism_data$genome
  txdb <- organism_data$txdb 
  
  loadEditors(editors_path, unique(df$editor))
}

# ===================================================================
# Worker Function Definition
# ===================================================================
# This worker function captures its own logs and returns them.
worker_fun <- function(query_num, gene_symbol, ensembl_id, target_aa, target_position, editor, edit_type) {
  
  if (debug){
    #Create separate directory in case it needs to dump the rda file
    dump_directory <- file.path(tmp_folder, preditr_temp, paste0("row_", query_num))
    dir.create(dump_directory, recursive = TRUE)
    options("tryCatchLog.write.error.dump.folder" = dump_directory)
    
  }

  
  tryCatchLog({
      
      # For 'multisession', objects must be loaded inside the worker.
      if (shiny) {
        logInfo(paste0("Worker ", query_num, ": Loading organism data and editors."))
        suppressMessages(
          organism_data <- loadOrganismData(organism)
        )
        genome <- organism_data$genome
        txdb <- organism_data$txdb
        loadEditors(editors_path, editor)
      }
      
      logInfo(paste0("Worker ", query_num, ": Starting process."))
      
      processed_res <- process_row(
        query_num, gene_symbol, ensembl_id, target_aa, target_position, editor, edit_type,
        genome, indexed_genome, organism, txdb, n_mismatches,
        n_max_alignments, flanking5, flanking3, tmp_folder
      )
      
      logInfo(paste0("Worker ", query_num, ": Finished process."))
      
      
      if (shiny){
        cat(paste0(query_num, "\n"), file = progress_file, append = TRUE)
      }
      
      #If there was no error, then delete the directory
      if (debug){
        unlink(dump_directory, recursive = TRUE)
      }
      
      
      return(processed_res)
      
    }, logged.conditions = NULL,
    
    error = function(e) {
      
      logError(paste0("Worker ", query_num, ": An unexpected error occurred."))
      error_res <- generateErrorOutput(query_num, n_mismatches)
      
      if (shiny){
        cat(paste0(query_num, "\n"), file = progress_file, append = TRUE)
      }
      
      return(error_res)
    })

}

# ===================================================================
# Parallel Execution
# ===================================================================
logInfo(paste0("Dispatching ", nrow(df), " tasks to parallel workers..."))

#Run
results <- future_pmap(
  .l = list(df$query_num, df$gene_symbol, df$ensembl_id, df$target_aa, df$target_position, df$editor, df$edit_type),
  .f = worker_fun
)

logInfo("All parallel tasks have completed.")

# ===================================================================
# Post-Processing and Output Generation
# ===================================================================

if (debug){
  #Create separate directory in case it needs to dump the rda file for this last stage
  final_dump_dir <- file.path(tmp_folder, preditr_temp, "end")
  dir.create(final_dump_dir, recursive = TRUE)
  options("tryCatchLog.write.error.dump.folder" = final_dump_dir)  
}


tryCatchLog({
  
  # -- Perform off-target searches and generate final output --
  if (off_targets) {
    logInfo("Performing off-target searches...")
    
    if (shiny) {
      suppressMessages(
      organism_data <- loadOrganismData(organism)
      )
      genome <- organism_data$genome
      txdb <- organism_data$txdb
    }
    offtargets_df <- findOffTargets(results, genome, indexed_genome, 
                                    n_mismatches, n_max_alignments, txdb)
    logInfo("Off-target search complete.")
  } else {
    logInfo("Skipping off-target searches.")
    offtargets_df <- data.frame()
  }
  
  logInfo("Preparing final output files...")
  generateOutput(df, job_name, output_path, results, offtargets_df, off_targets,
                 organism, editors_path, non_targeting_controls, flanking5, flanking3,
                 genome, indexed_genome, n_mismatches, n_max_alignments, txdb)
  
  logInfo(paste0("Results file created at: ", file.path(output_path, paste0(job_name, "_results.csv"))))
  
  logInfo("Finalizing log...")
  
  #These are here because once the log is loaded as a table, nothing can be appended to it
  logInfo(paste0("Log file created at: ", file.path(output_path, paste0(job_name, ".log"))))
  logInfo(paste("Job", job_name, "finished successfully."))
  
  log_table <- read.delim(file.path(tmp_folder, preditr_temp, paste0(job_name, ".log")),
                          header = FALSE)
  
  #Remove columns that are unnecessary in the log
  log_table$V2 <- NULL
  log_table$V4 <- NULL
  log_table$V5 <- NULL
  
  write.table(log_table, file = file.path(output_path, paste0(job_name, ".log")),
              row.names = FALSE, col.names = FALSE)
  
  
  # ===================================================================
  # Cleanup
  # ===================================================================
  if (dir.exists(file.path(tmp_folder, preditr_temp))) {
    unlink(file.path(tmp_folder, preditr_temp), recursive = TRUE)
  }
  
  cat("PrEditR run finished successfully.\n")
  clearLoggers()
  quit(status = 0)
  
}, logged.conditions = NULL,

  error = function(e){
  
  .Last <- function(){
    clearLoggers()
    #stop(e)
  }
  
  quit(status = 1, runLast = TRUE)
})
