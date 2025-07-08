generateWindowSeqs <- function(genome, cds_coordinates, target_position, strand, 
                               candidate_guides, alleles, editor, edit_type, flags){
  
  wildtype_aa_seqs <- c()
  mutant_aa_seqs <- c()
  
  #Get the DNA and protein_seq
  coding_sequence <- paste0(getSeq(genome, cds_coordinates), collapse="")
  coding_sequence_ob <- DNAString(x=coding_sequence, start=1, nchar=NA)
  protein_seq <- translate(coding_sequence_ob, genetic.code=GENETIC_CODE, no.init.codon = FALSE)
  
  #Get the editing window 
  editing_weights_matrix <- get(editor)@editingWeights
  editing_weights <- editing_weights_matrix[toupper(edit_type),]
  editing_window_indices <- c(which(editing_weights != 0)[1], 
                              tail(which(editing_weights != 0), 1))
  
  editing_window <- c(as.numeric(colnames(editing_weights_matrix))[editing_window_indices[1]], 
                      as.numeric(colnames(editing_weights_matrix))[editing_window_indices[2]])
  
  editing_window_length <- abs(abs(editing_window[1]) - abs(editing_window[2]))
  
  #Edit to be performed
  target_letter <- toupper(substr(edit_type, 1, 1))
  new_letter <- toupper(substr(edit_type,3, 3))
  
  #Calculate the codon positions
  codon_relative_end <- target_position*3 #These positions work on the coding strand as extracted a few lines before. Not on the reverse complement directly
  codon_relative_middle <- codon_relative_end-1
  codon_relative_start <- codon_relative_middle-1
  
  #Get the flanking sequence dna. It is the same for all, but the edit window is shifted for each
  flanking_seq_min <- max(c(codon_relative_start-3*7,
                            1))
  
  if ((codon_relative_start-3*7) < 1){ #There was a trim at the beginning of the sequence
    
    start_base_trim <- abs(1 - abs(codon_relative_start-3*7))
    
  } else {
    
    start_base_trim <- 0
  }
  
  flanking_seq_max <- min(c(codon_relative_end+3*7,
                            nchar(coding_sequence)))
  
  if (codon_relative_end+3*7 > nchar(coding_sequence)){ #There was a trim at the end of the sequence
    
    end_base_trim <- codon_relative_end+3*7  - nchar(coding_sequence)
    
  } else {
    
    end_base_trim <- 0
  }
  
  dna_flanking_seq <- DNAString(x=substr(coding_sequence, flanking_seq_min, flanking_seq_max), start=1, nchar=NA)
  

  #Same AA flanking string for all
  wildtype_flanking_aa <- as.character(translate(dna_flanking_seq, 
                                                 genetic.code = GENETIC_CODE, no.init.codon = TRUE))
  

  
  for (g in 1:length(candidate_guides)){
    
    #Before doing anything, if there is a relevant flag, return what corresponds
    
    if (flags[g] == "exon-intron"){
      
      wildtype_aa_seqs <- c(wildtype_aa_seqs, "Edit window spans exon-intron boundary")
      mutant_aa_seqs <- c(mutant_aa_seqs, "Edit window spans exon-intron boundary")
      next
    }
    
    if (as.character(candidate_guides[g]@strand) == strand){
      
      same_side <- TRUE
      #print("same side")
    } else {
      
      same_side <- FALSE
    }
    
    if (same_side){
      
      guide <- candidate_guides[g]$protospacer
      
    } else {
      
      guide <- reverseComplement(candidate_guides[g]$protospacer)
      #guide <- complement(candidate_guides[g]$protospacer)
    }
      
      #Then this guide, as it is, should perfectly align somewhere with the dna flanking sequence
      #Mismatches will be heavily penalized because no indels should exist
      
      
      substring_alignment <- findLongestTrimmedMatch(as.character(guide),
                                                     as.character(dna_flanking_seq))
      
      substring <- substring_alignment$substring
      start_alignment <- substring_alignment$start
      end_alignment <- substring_alignment$end
      
      #print(g)
      #print(dna_flanking_seq)
      #print(wildtype_flanking_aa)
      #print(guide)
      #print(substring)
      #print(start_alignment)
      #print(end_alignment)
      
      
      
      
      if (same_side){
        
        #This part assumes that the entire guide is on the flanking sequence. It is not the case for partial alignments
        #like when a guide spans exon-intron. The flag guides detects guides whose edit window span that interface, 
        #but there are cases in which the edit window is completely  on the coding sequence and the guide extends 
        #to the intron. Those are not flagged. But will fail here because the end alignment position is not the base just before the PAM.
        
        if (nchar(substring) == get(editor)@spacer_length){
          
          wildtype_allele_window <- c(end_alignment+1-max(abs(editing_window))
                                      ,end_alignment+1-min(abs(editing_window)))
          
          wildtype_allele_seq <- substr(as.character(dna_flanking_seq), wildtype_allele_window[1], wildtype_allele_window[2])
          
        } else { #We need to use the start positions
          
          
          wildtype_allele_window <- c(start_alignment + get(editor)@spacer_length - max(abs(editing_window)), 
                                      start_alignment + get(editor)@spacer_length - min(abs(editing_window)))
          
          wildtype_allele_seq <- substr(as.character(dna_flanking_seq), wildtype_allele_window[1], wildtype_allele_window[2])
        }
        
        
        
      } else {
        
        wildtype_allele_window <- c(start_alignment-1+min(abs(editing_window))
                                    ,start_alignment-1+max(abs(editing_window)))
        
        wildtype_allele_seq <- as.character(complement(DNAString(x = substr(as.character(dna_flanking_seq), wildtype_allele_window[1], wildtype_allele_window[2]),
                                         start = 1, nchar = NA)))
      }

      
      
      
      mutant_allele_seq <- gsub(target_letter, new_letter, wildtype_allele_seq) #Assumes that all bases within the window that can be edited will be edited
      
      mutant_dna_flanking_seq <- paste0(substr(as.character(dna_flanking_seq), 1, wildtype_allele_window[1]-1),
                                        mutant_allele_seq,
                                      substr(as.character(dna_flanking_seq), wildtype_allele_window[2]+1, nchar(as.character(dna_flanking_seq))))
      
      mutant_aa_flanking_seq <- as.character(translate(DNAString(x=mutant_dna_flanking_seq, start=1, nchar=NA), 
                                            genetic.code = GENETIC_CODE, no.init.codon = TRUE))
      #print(wildtype_allele_seq)
      #print(wildtype_flanking_aa)
      #print(mutant_allele_seq)
      #print(mutant_aa_flanking_seq)
      
      if (wildtype_allele_window[1]-1 %% 3 == 0){
        
        
        first_aa_in_window <- (wildtype_allele_window[1]-1)/3 + 1 #+1 to include it
        
      } else {
        
        
        first_aa_in_window <- floor((wildtype_allele_window[1]-1)/3)+1

        
      }
        
      remaining_bases <- nchar(as.character(dna_flanking_seq)) - (wildtype_allele_window[2]+1)
      
      if (remaining_bases %% 3 == 0){
        
        last_aa_in_window <- (nchar(dna_flanking_seq) - remaining_bases)/3
        
      } else {
        
        last_aa_in_window <- (nchar(dna_flanking_seq) - (remaining_bases - remaining_bases%%3))/3
        
      }   
      
      #print(wildtype_allele_window)
      #print(first_aa_in_window)
      #print(last_aa_in_window)
      
      wildtype_aa_seq <- paste0(strrep("-", ifelse(start_base_trim != 0,start_base_trim/3 +1, 0)), 
                                substr(wildtype_flanking_aa, 1, first_aa_in_window-1), "|", 
                                substr(wildtype_flanking_aa, first_aa_in_window, last_aa_in_window), "|",
                                substr(wildtype_flanking_aa, last_aa_in_window+1, nchar(wildtype_flanking_aa)), 
                                strrep("-", end_base_trim/3))
      
      if (alleles$variant[g] == "silent"){
        
        
        mutant_aa_seq <- paste0(strrep("-", ifelse(start_base_trim != 0, start_base_trim/3 +1, 0)),
                                substr(wildtype_flanking_aa, 1, first_aa_in_window-1), "|", 
                                substr(wildtype_flanking_aa, first_aa_in_window, last_aa_in_window), "|",
                                substr(wildtype_flanking_aa, last_aa_in_window+1, nchar(wildtype_flanking_aa)), 
                                strrep("-", end_base_trim/3))
        
      } else {
        
        mutant_aa_seq <- paste0(strrep("-", ifelse(start_base_trim != 0, start_base_trim/3 +1, 0)), 
                                substr(mutant_aa_flanking_seq, 1, first_aa_in_window-1), "|", 
                                substr(mutant_aa_flanking_seq, first_aa_in_window, last_aa_in_window), "|",
                                substr(mutant_aa_flanking_seq, last_aa_in_window+1, nchar(mutant_aa_flanking_seq)), 
                                strrep("-", end_base_trim/3))
        
        #Some guides can make it to this point as missense because they are missense for other mutations in the window, not necessarily the desired target
        #This part filters them out. An example of this is S338 in Rela (ENSMUST00000025867)
        
        if (substr(wildtype_aa_seq,9,9) == substr(mutant_aa_seq, 9, 9)){ #Ninth character because it is centered at 8 for the target but 9 including the vertical bar | for the start of the window
          
          wildtype_aa_seq <- "SKIP"
          mutant_aa_seq <- "SKIP"
        }
        
        
      }
      
      
      
      wildtype_aa_seqs <- c(wildtype_aa_seqs, wildtype_aa_seq)
      mutant_aa_seqs <- c(mutant_aa_seqs, mutant_aa_seq)
      
  }
  
  return(list(wildtype_seqs = wildtype_aa_seqs,
              mutant_seqs = mutant_aa_seqs))
  
  
}