flagIsoforms <- function(organism, uniprot_idx){
    
    ParallelLogger::logInfo("Checking for isoforms...")
    
    iso_file <- file.path(referenceMapsDir(organism), "has_isoforms.rds")
    if (!file.exists(iso_file)) {
      ParallelLogger::logInfo("No has_isoforms map for this organism; treating all as non-isoform.")
      return(rep(FALSE, length(uniprot_idx)))
    }
    env <- readRDS(iso_file)
    
    unique_ids <- unique(uniprot_idx)
    unique_ids <- unique_ids[!is.na(unique_ids) & unique_ids != ""]
    
    check_results <- vapply(unique_ids, function(id) {
      exists(as.character(id), envir = env, inherits = FALSE)
    }, logical(1))
    
    final_presence <- check_results[match(uniprot_idx, names(check_results))]
    
    final_presence[is.na(final_presence)] <- FALSE
    
    ParallelLogger::logInfo("Isoform check completed.")
    
    return(final_presence)
  
}