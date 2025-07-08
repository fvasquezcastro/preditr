annotateEdits <- function(guideSet, txdb, genome, gene_symbol, base_editor, edit_type, ensembl_id, cds_coordinates){
  
  gene_sequence <- paste0(getSeq(genome, cds_coordinates), collapse="")
  
  if (substr(gene_sequence, 1, 3) != "ATG"){
    
    #The alleles annotation fails when the coding sequence retrieved does not start with ATG. 
    #Although unexpected, for some reason it seems to be the case for ENST00000634879. Possibly due to an error in the database
    return(guideSet) 
              
  }
  
  editing_matrix <- get(base_editor)@editingWeights
  editing_weights <- editing_matrix[toupper(edit_type),]
  
  start_position <- which(diff(c(0, editing_weights)) == 1) #This assumes that the optimal edit window is represented by weights of 1 and is continuous, not fragmented
  end_position <- which(diff(c(editing_weights, 0)) == -1)
  
  editing_window <- c(as.integer(colnames(editing_matrix)[start_position]), as.integer(colnames(editing_matrix)[end_position]))
  
  tryCatch({
    txtable <- getTxInfoDataFrame(tx_id=ensembl_id, #Get txdb table from txdb object
                                  txObject=txdb,
                                  bsgenome=genome)
    
    suppressMessages(
                      guideSet <- addEditedAlleles(guideSet,
                                 baseEditor=get(base_editor),
                                 txTable=txtable,
                                 editingWindow=editing_window))
    
    
    guideSet <- guideSet[order(-guideSet$score_missense,
                               guideSet$score_nonsense, 
                               guideSet$score_silent)] #Sort prioritizing missense over nonsense and silent
    
    return(guideSet)
    
    
  }, error = function(e){
    
    if (conditionMessage(e) == "The specified tx_id has a CDS with incomplete length."){
      return(guideSet) 
      
    } else {
      
      stop(e) #Unexpected error
    }
    
  })

}