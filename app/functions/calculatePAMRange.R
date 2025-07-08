calculatePAMRange <- function(target_aa, editor, edit_type, codon_absolute_locations, codon_seq, strand){
  
  codon_absolute_start <- codon_absolute_locations[1] #Always in increasing order, regardless of the strand sign
  codon_absolute_middle <- codon_absolute_locations[2]
  codon_absolute_end <- codon_absolute_locations[3]
  
  #Get the editing window 
  editing_weights_matrix <- get(editor)@editingWeights
  editing_weights <- editing_weights_matrix[toupper(edit_type),]
  editing_window_indices <- c(which(editing_weights != 0)[1], 
                      tail(which(editing_weights != 0), 1))
  
  editing_window <- c(as.numeric(colnames(editing_weights_matrix))[editing_window_indices[1]], 
                      as.numeric(colnames(editing_weights_matrix))[editing_window_indices[2]])
  
  target_letter <- toupper(substr(edit_type, 1,1))
  #CRUCIAL: Remember that codon_seq is retrieved as the sequence in the 5'-3' direction regardless of strand specified
  comp_codon <- as.character(complement(codon_seq))
  
  current_strand_ranges <- c()
  opposite_strand_ranges <- c()
  
  
  if (strand == "+"){ #SCENARIO A: Gene found on the positive strand
    
    for (l in 1:3){
      
      letter = toupper(substr(as.character(codon_seq), l, l))
      comp_letter <- toupper(substr(comp_codon, l, l))
      
      if (letter == target_letter){ #SCENARIO A1: guides on the positive strand
        
        current_strand_ranges <- c(current_strand_ranges, 
                                    codon_absolute_locations[l]+min(abs(editing_window)),
                                    codon_absolute_locations[l]+max(abs(editing_window)))
        
      }
      
      if (comp_letter == target_letter){ #SCENARIO A2: guides on the negative strand
        
        
        opposite_strand_ranges <- c(opposite_strand_ranges,
                                    codon_absolute_locations[l]-max(abs(editing_window)),
                                    codon_absolute_locations[l]-min(abs(editing_window)))
      }
      
    }
    
  }
  
  if (strand == "-"){ #SCENARIO B: gene found on the negative strand
      
      for (l in 1:3){
        
        letter = toupper(substr(as.character(reverse(codon_seq)), l, l)) #Because codon_seq is returned in 5'->3' regardless of the strand
        comp_letter = toupper(substr(as.character(complement(reverse(codon_seq))), l, l))
        
        
        if (letter == target_letter){ #
          
          current_strand_ranges <- c(current_strand_ranges, 
                                      codon_absolute_locations[l]-max(abs(editing_window)),
                                      codon_absolute_locations[l]-min(abs(editing_window)))
        
      }
      
      
        if (comp_letter == target_letter){
          
          opposite_strand_ranges <- c(opposite_strand_ranges,
                                      codon_absolute_locations[l]+min(abs(editing_window)),
                                      codon_absolute_locations[l]+max(abs(editing_window)))
          
          
        }
        
        
      
     }
  

  }
      
    
  return(list(current_strand_ranges = current_strand_ranges,
              opposite_strand_ranges = opposite_strand_ranges))
  
}