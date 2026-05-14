checkIDs <- function(ensembl_id){
  
  #PrEditR.R does cross-mapping from Uniprot to Ensembl and back. The searches are ultimately based
  #on Ensembl ID because a txdb object is queried. If the ID is empty at this point, this will trow an error.
  
  if (is.na(ensembl_id) || ensembl_id == "") {
    
      #logError("UNIPROT ID does not match to any entry in the database.
      #     Please check for typographical errors or consider searching by Ensembl ID instead")
      return(1)
  }
  
  return(0)
  
}