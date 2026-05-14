trimEnsembl <- function(ensembl_idx){
  #If the Ensembl IDs provided are 
  
  trimmed_idx <- gsub("\\.[0-9]+", "", ensembl_idx)
  
  
  return(trimmed_idx)
}