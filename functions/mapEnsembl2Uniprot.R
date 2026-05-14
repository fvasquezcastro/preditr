mapEnsembl2Uniprot <- function(organism, ensembl_idx) {
  
  ParallelLogger::logInfo("Mapping Ensembl IDs to UNIPROT IDs...")
  
  # Normalize input
  ensembl_idx <- ifelse(is.na(ensembl_idx) | ensembl_idx == "", NA_character_, ensembl_idx)
  
  map_env <- readRDS(file.path("maps", organism, "ensembl_to_uniprot.rds"))
  
  `%||%` <- function(x, y) if (is.null(x)) y else x
  
  ensembl_to_uniprot <- function(ids) {
    vapply(ids, function(id) {
      
      if (is.na(id)) {
        NA_character_
      } else {
        map_env[[id]] %||% NA_character_
      }
      
    }, character(1))
  }
  
  uniprot_idx <- ensembl_to_uniprot(ensembl_idx)
  
  ParallelLogger::logInfo("Mapping completed.")
  
  return(uniprot_idx)
}