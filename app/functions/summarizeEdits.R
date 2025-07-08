summarizeEdits <- function(sequences, target_position){
  
  edits <- c()
  
  for (i in 1:length(sequences$wildtype_seqs)){
    
    if (sequences$wildtype_seqs[i] == "SKIP" | sequences$wildtype_seqs[i] == "Edit window spans exon-intron boundary"){
      next
    }
    
    bars_positions <- gregexpr("\\|", sequences$wildtype_seqs[i])[[1]]
    first_bar <- bars_positions[1]
    second_bar <- bars_positions[2]
    
    #It is known that the the 9th position on the string matches the target_position on the protein
    #because the sequence has +/- 7 aa plus vertical bars around the edit window, which contains the target position
    
    first_aa_in_window_rel <- first_bar+1
    last_aa_in_window_rel <- second_bar-1
    
    edited <- c()
    
    for (p in first_aa_in_window_rel:last_aa_in_window_rel){
      
      wildtype_aa <- substr(sequences$wildtype_seqs[i], p, p)
      mutant_aa <- substr(sequences$mutant_seqs[i], p, p)
      abs_position <- (p-9)+target_position
        
      if (wildtype_aa != mutant_aa){
        
        edited <- c(edited, paste0(wildtype_aa, abs_position, mutant_aa))
        
      }
    }
    
    edits <- c(edits, paste(edited, collapse = ", "))
    
    
  }
  
  return(edits)
  
}