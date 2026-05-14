generateErrorOutput <- function(row_num, off_targets, n_mismatches,
                                gene_symbol, ensembl_id){
  
  error_message <- ifelse(
    (is.na(gene_symbol) || gene_symbol == "") && (is.na(ensembl_id) || ensembl_id == ""),
    "UNIPROT ID does not match to any entry in the database.
    Please check for typos or consider searching by Gene Symbol or Ensembl ID instead",
    "Unexpected Error"
  )
  
  new_row <- data.frame(query_num = as.character(row_num),
                        ensembl_id_used = "",
                        gene_strand = "",
                        protospacer_seq = "",
                        percent_gc = "",
                        protospacer_strand = "",
                        pam_seq = "",
                        chromosome = "",
                        pam_coordinates = "",
                        mutation_type = "",
                        wildtype_sequence = "",
                        mutant_sequence = "",
                        edits = "",
                        warnings = "",
                        error = "Unexpected Error")
  
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
  
  if (off_targets){
    
    #Append the columns that correspond to the desired number of mismatches for alignments
    alignments_cols <- paste0("alignments_n", 0:n_mismatches)
    alignments_df <- data.frame(matrix(ncol = length(alignments_cols), nrow = 0))
    
    
    alignments_df[] <- lapply(alignments_df, as.character)
    
    #Empty row for alignments
    alignments_row <- rep("", n_mismatches+1)
    alignments_df <- rbind(alignments_df, alignments_row)
    
    colnames(alignments_df) <- alignments_cols
    
    partial_df <- cbind(new_row, alignments_df)
    
  } else {
    
    partial_df <- new_row
  }
  
  partial_output <- list(
    partial_df = partial_df,
    partial_guideset = NULL
  )
  
  return(partial_output)
}