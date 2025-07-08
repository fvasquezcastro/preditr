generateErrorOutput <- function(row_num, n_mismatches){
  
  new_row <- data.frame(row_num = as.character(row_num),
                        ensembl_id_used = "",
                        gene_strand = "",
                        protospacer_seq = "Unexpected error",
                        percent_gc = "",
                        protospacer_strand = "",
                        pam_seq = "",
                        chromosome = "",
                        pam_coordinates = "",
                        mutation_type = "",
                        wildtype_sequence = "",
                        mutant_sequence = "",
                        edits = "")
  
 
    
    enzymes <- data.frame(
      EcoRI = "",
      KpnI = "",
      BsmBI = "",
      BsaI = "",
      BbsI = "",
      PacI = "", 
      MluI = ""
    )
    
    new_row <- cbind(new_row, enzymes)
  
  
  #Append the columns that correspond to the desired number of mismatches for alignments
  alignments_cols <- paste0("alignments_n", 0:n_mismatches)
  alignments_df <- data.frame(matrix(ncol = length(alignments_cols), nrow = 0))
  
  
  alignments_df[] <- lapply(alignments_df, as.character)
  
  #Empty row for alignments
  alignments_row <- rep("", n_mismatches+1)
  alignments_df <- rbind(alignments_df, alignments_row)
  
  colnames(alignments_df) <- alignments_cols
  
  partial_df <- cbind(new_row, alignments_df)
  
  partial_output <- list(
    partial_df = partial_df,
    partial_guideset = NULL
  )
  
  return(partial_output)
}