findAbsoluteCodonLocation <- function(genome, organism, txdb, gene_symbol, ensembl_id, target_position, target_aa){
  
  if (is.na(ensembl_id) | ensembl_id == ""){
    
    logInfo("No ENSEMBL ID provided. Will carry out an exhaustive search for all ENSEMBL IDs in the database and choose the first one it is correctly located at for further analyses")
    location <- findAnyACL(genome, gene_symbol, txdb, target_position, target_aa)
    
    if (is.null(location)) {
      logError("Amino acid not found at the position specified for any ENSEMBL ID in the database")
    }
    
  } else {
    
    location <- findACLbyID(genome, txdb, ensembl_id, target_position, target_aa)
    return(location)
  }
  
  
  
}