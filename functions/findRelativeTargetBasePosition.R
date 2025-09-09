findRelativeTargetBasePosition <- function(target_aa, edit_type, strand, codon_seq){
  
  target_letter <- substr(toupper(edit_type),1,1) #DNA letter that the editor can target
  

  if (strand == "+"){
    
    codon_complement <- as.character(complement(DNAString(x=codon_seq, start=1, nchar=NA))) #For edits on the opposite strand that force the cellular machinery to correct the current strand
    
    #This if statement is for edits directly on the current strand for the positive strand
    if (grepl(target_letter, codon_seq)){ 
      
      split_codon <- strsplit(codon_seq, "")[[1]]
      positions <- which(split_codon == target_letter) #Get all positions for the letter in the codon
      edited_codons <- generateEditedCodons(codon_seq, positions, edit_type)
      
      translated_codons <- c()
      
      for (e in edited_codons){
        translated_codons <- c(translated_codons, as.character(translate(DNAString(x=e, start=1, nchar=NA), genetic.code=GENETIC_CODE, no.init.codon = FALSE)))
      
      }
      
      if (toupper(target_aa) %in% translated_codons){ #If any edit can give the same original amino acid, the edit is not achievable (dubious performance)
        current_strand_relative_target_positions <- -Inf
      } else {
        
        current_strand_relative_target_positions <- positions #All possible positions in the codon that are editable. If there are multiple positions, then there will be multiple PAM ranges that can overlap
      }
    
    } else { #If there is no target letter in the codon_seq
      current_strand_relative_target_positions <- -Inf
    }
    
    #This if statement is for edits on the opposite strand that would affect the current strand through cellular repair machinery. Current strand refers to the strand in which the transcript was obtained from in the db; it is not a user-specified parameter
    if (grepl(target_letter, codon_complement)){
      
      split_codon_complement <- strsplit(codon_complement, "")[[1]]
      positions_complement <- which(split_codon_complement == target_letter) #Get all positions for the letter in the codon
      edited_codons_complement <- generateEditedCodons(codon_complement, positions_complement, edit_type)
      
      translated_complement_codons <- c()
      
      for (e in edited_codons_complement){
        
        #Find the complement to each of these (what the current strand would look like after the edit on the opposite strand) and translate
        translated_complement_codons <- c(translated_complement_codons, as.character(translate(complement(DNAString(x=e, start=1, nchar=NA)), genetic.code = GENETIC_CODE,  no.init.codon = FALSE)))
        
      }
      
      if (toupper(target_aa) %in% translated_complement_codons){
        
        opposite_strand_relative_target_positions <- -Inf
        
      } else{
        
        opposite_strand_relative_target_positions <- positions_complement
      }
      
      
    } else {
      
      opposite_strand_relative_target_positions <- -Inf
      
    }
}
  
  
  if (strand == "-"){
    
    reverse_codon_seq <- reverse(codon_seq) #Because it is passed as the 5'-3' sequence even if it is on the 3'-5' end. It is only reversed, not "reverse-complemented". For example, for a tyrosine TAC -> CAT
  
    
    if (grepl(target_letter, reverse_codon_seq)){ #For edits on the current strand, which in this case is the negative one
      
      
      split_reverse_codon_seq <- strsplit(reverse_codon_seq, "")[[1]]
      split_reverse_codon_positions <- which(split_reverse_codon_seq == target_letter)
      reverse_codons_edited <- generateEditedCodons(reverse_codon_seq, split_reverse_codon_positions, edit_type)
      
      translated_reverse_codons <- c()
      
      for (r in reverse_codons_edited){
        
        translated_reverse_codons <- c(translated_reverse_codons, as.character(translate(DNAString(x=reverse(r), start=1, nchar=NA), genetic.code=GENETIC_CODE, no.init.codon = FALSE))) #The codons must be reversed before the translation since the translation table is in the 5'-3' direction
        
      }
      
      if (toupper(target_aa) %in% translated_reverse_codons){
        
        current_strand_relative_target_positions <- -Inf
      
      } else {
        
        current_strand_relative_target_positions <- split_reverse_codon_positions
        
      }
      
    } else {
      
      current_strand_relative_target_positions <- -Inf #Cannot be edited directly on the negative strand
      
    }
    
    complement_reverse_codon_seq <- as.character(complement(DNAString(x=reverse_codon_seq, start=1, nchar=NA)))
    
    if (grepl(target_letter, complement_reverse_codon_seq)){
      
      split_complement_reverse_codon_seq <- strsplit(complement_reverse_codon_seq, "")[[1]]
      split_complement_reverse_codon_positions <- which(split_complement_reverse_codon_seq == target_letter)
      complement_reverse_codons_edited <- generateEditedCodons(complement_reverse_codon_seq, split_complement_reverse_codon_positions, edit_type)
      
      
      translated_complement_reverse_codons <- c()
      
      for (cr in complement_reverse_codons_edited){
        
        translated_complement_reverse_codons <- c(translated_complement_reverse_codons, as.character(translate(complement(DNAString(x=reverse(cr), start=1, nchar=NA)), genetic.code = GENETIC_CODE,  no.init.codon = FALSE)))
      }
      
      if (target_aa %in% translated_complement_reverse_codons){
        
        opposite_strand_relative_target_positions <- -Inf
        
      } else {
        
        opposite_strand_relative_target_positions <- split_complement_reverse_codon_positions
        
      }
      
    } else {
      
      opposite_strand_relative_target_positions <- -Inf
    }
    
    
  }
  
  
  return(list(
    current_strand = current_strand_relative_target_positions,
    opposite_strand = opposite_strand_relative_target_positions
  ))
  
}