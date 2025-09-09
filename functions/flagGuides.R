flagGuides <- function(candidate_guides, cds_coordinates, edit_type, editor, ensembl_id, txdb, genome){
  
  #Check if the transcript is truncated
  is_truncated <- FALSE
  
  
  txtable <- tryCatch({

     getTxInfoDataFrame(tx_id=ensembl_id,
                                  txObject=txdb,
                                  bsgenome=genome)
  }, error = function(e){
    
    if (conditionMessage(e) == "The specified tx_id has a CDS with incomplete length."){
      logInfo("WARNING: This transcript is truncated in the database.")
      is_truncated <<- TRUE
      return(NULL)
      }
    
  })
  
   if (is_truncated){
     
     flags <- rep("truncated", length(candidate_guides))
     return(flags)
   }
  
  #Get edit window relative positions
  editing_weights_matrix <- get(editor)@editingWeights
  editing_weights <- editing_weights_matrix[toupper(edit_type),]
  editing_window_indices <- c(which(editing_weights != 0)[1], 
                              tail(which(editing_weights != 0), 1))
  
  editing_window <- c(as.numeric(colnames(editing_weights_matrix))[editing_window_indices[1]], 
                      as.numeric(colnames(editing_weights_matrix))[editing_window_indices[2]])
  
  
  cds_starts <- cds_coordinates@ranges@start
  cds_ends <- end(cds_coordinates@ranges)
  
  
  #Will see if any edit window range goes over these values
  flags <- c()
  
  for (g in 1:length(candidate_guides)){
    
    #print(g)
    guide_strand <- as.character(candidate_guides[g]@strand)
    pam_coordinates <- candidate_guides[g]$pam_site
    
    if (guide_strand == "+"){
      
      edit_window_lower_pos <- pam_coordinates - max(abs(editing_window))
      edit_window_upper_pos <- pam_coordinates - min(abs(editing_window))
      
    } else {
      
      edit_window_lower_pos <- pam_coordinates + min(abs(editing_window))
      edit_window_upper_pos <- pam_coordinates + max(abs(editing_window))
      
    }
    
    
    #Will throw a warning for 3'-truncated transcripts such as ENST00000373865
    cds_3prime_boundary <- max(cds_ends[which(cds_ends < edit_window_upper_pos)])
    
    #Will throw a warning for 5'-truncated transcripts
    cds_5prime_boundary <- max(cds_starts[which(cds_starts < edit_window_upper_pos)])
    
    if (cds_3prime_boundary > edit_window_lower_pos | cds_5prime_boundary > edit_window_lower_pos) {
      
      flags <- c(flags, "exon-intron")
    
    } else {
        
      flags <- c(flags, "")
      
      }
    
    
  }
  
  
  return(flags)
}