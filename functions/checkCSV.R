checkCSV <- function(csv_path){
  
  tryCatch({
    
    csv <- read.csv(csv_path)

  } error = stop("Error loading the .CSV file. Verify that the path is correct"))
  
  columns <- colnames(csv)
  
  if (c("gene_symbol", "ensembl_id", "target_aa", "target_position", "editor", "edit_type") %in% columns){
    
    return(csv)
  }
  else {
    
    stop("One of the following columns is missing: gene_symbol, ensembl_id, target_aa, target_position, editor, edit_type")
  }
  
  
  ##Add functionality to check that no row is empty, no row is missing target_aa, target_position, editor, edit_type and gene_symbol/ensembl_id, 
  #If so, indicate which specific rows have any error
  
  #All target_positions have to be integers
  #All target_aa have to be S, T, Y
  #The editor must be an editor that we have here or show which row is using an editor that is not allowed
}