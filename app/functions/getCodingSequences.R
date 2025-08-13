getCodingSequences <- function(gene_symbol, organism) {
  
  txdb_object = paste0("txdb_", organism)
    
  coordinates <- queryTxObject(txObject=get(txdb_object), #Find coordinates for a specific gene
                               featureType="cds",
                               queryColumn="gene_symbol",
                               queryValue=gene_symbol)
  
  if (length(coordinates) == 0){
    
    logError("Gene symbol not found for this organism.")
    stop()
  }
  else {
    
    tryCatch(
      {
      cds <- getSeq(genome, coordinates)
      
      return(list(cds = cds, coordinates = coordinates))
      
      },
      error = function(p){
        
        logError("Gene not found in the reference genome.")
        stop()
    
      }
  
    )
  
  }
  
}