mapUniprot2Ensembl <- function(organism, uniprot_idx) {
  
  ParallelLogger::logInfo("Mapping UNIPROT IDs to Ensembl IDs...")
  
  # Normalize input
  uniprot_idx <- ifelse(is.na(uniprot_idx) | uniprot_idx == "", NA_character_, uniprot_idx)
  
  map_file <- file.path(referenceMapsDir(organism), "uniprot_to_ensembl.rds")
  if (!file.exists(map_file)) {
    ParallelLogger::logInfo("No uniprot_to_ensembl map for this organism; skipping UniProt->Ensembl mapping.")
    return(rep(NA_character_, length(uniprot_idx)))
  }
  map_env <- readRDS(map_file)
  
  `%||%` <- function(x, y) if (is.null(x)) y else x
  
  uniprot_to_ensembl <- function(ids) {
    vapply(ids, function(id) {
      
      if (is.na(id)) {
        NA_character_
      } else {
        map_env[[id]] %||% NA_character_
      }
      
    }, character(1))
  }
  
  ensembl_idx <- uniprot_to_ensembl(uniprot_idx)
  
  ParallelLogger::logInfo("Mapping completed.")
  
  return(ensembl_idx)
}