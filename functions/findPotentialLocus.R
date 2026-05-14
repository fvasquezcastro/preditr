findPotentialLocus <- function(genome, ensembl_id, target_position, txdb) {
  
  cds_coordinates <- crisprDesign::queryTxObject(txObject=txdb, #Find cds_coordinates for a specific transcript
                               featureType="cds",
                               queryColumn="tx_id",
                               queryValue=ensembl_id)
  

  if (length(cds_coordinates) == 0){
    #logError("ENSEMBL ID provided does not exist in the database. Only provide IDs without version numbers (<ID>.<version_number>)")
    return(NULL)  
  }
  
  gene_symbol <- cds_coordinates$gene_symbol[1]
  
  cds <- Biostrings::getSeq(genome, cds_coordinates) #coding sequences
  
  
  codon_relative_end <- (target_position)*3 #Must be included in the range
  codon_relative_start <- codon_relative_end - 2 #Must be included in the range
  

  current_region <- which(cumsum(cds@ranges@width) - codon_relative_start >= 0)[1]

  
  if (is.na(current_region)){
    
    #There could be a chance that the position targeted exists in the transcript but the transcript is truncated at 3'
    tryCatch({
      
      txtable <- crisprDesign::getTxInfoDataFrame(tx_id=ensembl_id, #Get txdb table from txdb object
                                    txObject=txdb,
                                    bsgenome=genome)
      
    }, error = function(e){
      
      if (conditionMessage(e) == "The specified tx_id has a CDS with incomplete length."){
        
        message(paste0("Position ", target_position, " is greater than the last position in transcript ", ensembl_id,  " , whose coding sequence is truncated at 3' in the database"))
        
        return(NULL)
      }
    })
    
    #last_aa <- dplyr::last(cumsum(cds@ranges@width))/3
    last_aa <- tail(cumsum(cds@ranges@width), 1) / 3
    
    message(paste0("Position ", target_position, " is greater than the last position in transcript ", ensembl_id, " which is ", last_aa))
    
    return(NULL)
  }
  
  #Retrieve abs coordinates the same way as in getWindowSeqs2()
  cds_abs_coordinates <- c()
  
  for (i in 1:length(cds_coordinates@ranges@start)){
    
    if (as.character(cds_coordinates@strand)[1] == "+"){
      
      cds_abs_coordinates <- c(cds_abs_coordinates,
                               c(cds_coordinates@ranges@start[i]:BiocGenerics::end(cds_coordinates@ranges)[i]))
      
    } else {
      
      cds_abs_coordinates <- c(cds_abs_coordinates,
                               c(BiocGenerics::end(cds_coordinates@ranges)[i]:cds_coordinates@ranges@start[i]))
      
    }
    
  }
    
  
    strand <- as.character(cds_coordinates@strand[1])
    
    return(list(
      potential_coordinates=cds_abs_coordinates[codon_relative_start:codon_relative_end],
      cds_coordinates = cds_coordinates,
      strand = strand,
      gene_symbol = gene_symbol
    ))
  
}