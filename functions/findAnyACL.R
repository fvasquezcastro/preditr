findAnyACL <- function(genome, gene_symbol, txdb, target_position, target_aa){
  
  
  coordinates <- queryTxObject(txObject=txdb,
                               featureType="cds",
                               queryColumn="gene_symbol",
                               queryValue=gene_symbol)
  
  if (length(coordinates) == 0){
    
    logError(paste0("The gene symbol ", gene_symbol, " does not exist in the database."))
    return(NULL)
    
  }
  
  ensembl_ids <- unique(coordinates@elementMetadata$tx_id)
    
  message(paste0("ENSEMBL IDs to check: ", paste(ensembl_ids, collapse = ", ")))
  
  for (e_id in ensembl_ids){
    
    location <- findACLbyID(genome, txdb, e_id, target_position, target_aa)
    
    if (!is.null(location)){ #That is, something was found
      
      break
      
    }
  }
  
  if (is.null(location)){ #Needed to check if the for loop ended because we checked all ENSEMBL IDs or the last ENSEMBL ID checked does actually contain the site
    
    logError("The amino acid indicated could not be found for any ENSEMBL ID.")
    
    return(NULL)
    
  }
    
  return(location)
    
}