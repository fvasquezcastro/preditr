mapUniprot2Ensembl <- function(organism, uniprot_idx) {
  
  ParallelLogger::logInfo("Mapping UNIPROT IDs to Ensembl IDs...")
  
  # Normalize input
  uniprot_idx <- ifelse(is.na(uniprot_idx) | uniprot_idx == "", NA_character_, uniprot_idx)
  
  map_env <- readRDS(file.path("maps", organism, "uniprot_to_ensembl.rds"))
  
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