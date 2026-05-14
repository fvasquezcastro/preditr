mapEnsembl2MGI <- function(ensembl_idx){
  
  ensembl_idx <- ifelse(ensembl_idx == "", NA, ensembl_idx) #Prevents errors during mapping
  
  map_env <- readRDS(file.path("maps", "mouse", "ensembl_to_mgi.rds"))
  
  #Define helper functions
  
  `%||%` <- function(x, y) if (is.null(x)) y else x
  
  ensembl_to_mgi <- function(ids) {
    vapply(ids, function(id) {
      if (is.na(id) || id == "") {
        ""  # Return empty string for NA or blank input
      } else {
        map_env[[id]] %||% ""  # Use mapping or fallback to empty string
      }
    }, character(1))
  }
  
  mgi_idx <- ensembl_to_mgi(ensembl_idx)
    
  return(mgi_idx)
  
}