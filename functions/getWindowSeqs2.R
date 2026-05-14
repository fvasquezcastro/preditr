getWindowSeqs2 <- function(genome, cds_coordinates, target_aa, target_position, strand, 
                           candidate_guides, editor, edit_type, flags,
                           absolute_codon_locations) {
  
  wildtype_aa_seqs <- c()
  mutant_aa_seqs <- c()
  warnings <- c()
  
  # 1. Get the DNA and protein_seq
  coding_sequence <- paste0(getSeq(genome, cds_coordinates), collapse="")
  coding_sequence_ob <- DNAString(x=coding_sequence, start=1, nchar=NA)
  protein_seq <- translate(coding_sequence_ob, genetic.code=GENETIC_CODE, no.init.codon = FALSE)
  
  # 2. Get editing window parameters
  editing_weights_matrix <- get(editor)@editingWeights
  editing_weights <- editing_weights_matrix[toupper(edit_type),]
  editing_window_indices <- c(which(editing_weights != 0)[1], 
                              tail(which(editing_weights != 0), 1))
  
  win_offsets <- as.numeric(colnames(editing_weights_matrix))
  edit_min_off <- win_offsets[editing_window_indices[1]]
  edit_max_off <- win_offsets[editing_window_indices[2]]
  editing_window_length <- abs(edit_max_off - edit_min_off) + 1
  
  target_letter <- DNAString(toupper(substr(edit_type, 1, 1)))
  new_letter <- DNAString(toupper(substr(edit_type, 3, 3)))
  
  # 3. Build the coordinate map
  cds_abs_coordinates <- c()
  for (i in 1:length(cds_coordinates@ranges@start)){
    if (as.character(cds_coordinates@strand)[1] == "+"){
      cds_abs_coordinates <- c(cds_abs_coordinates,
                               c(cds_coordinates@ranges@start[i]:end(cds_coordinates@ranges)[i]))
    } else {
      cds_abs_coordinates <- c(cds_abs_coordinates,
                               c(end(cds_coordinates@ranges)[i]:cds_coordinates@ranges@start[i]))
    }
  }
  
  # 4. Define the flanking window
  codon_position <- target_position*3 - 2
  flanking_start <- max(1, codon_position - 21)
  flanking_end <- min(length(cds_abs_coordinates), codon_position + 23)
  
  missing_aa_start <- (abs(min(0, codon_position - 22))) / 3
  missing_aa_end <- (max(0, (codon_position + 23) - length(cds_abs_coordinates))) / 3
  
  flanking_abs_coordinates <- cds_abs_coordinates[flanking_start:flanking_end]
  flanking_dna_seq <- substr(coding_sequence, flanking_start, flanking_end)
  
  wildtype_flanking_protein <- as.character(translate(DNAString(flanking_dna_seq), 
                                                      genetic.code = GENETIC_CODE, 
                                                      no.init.codon = TRUE))
  
  # 5. Process each Guide
  for (g in 1:length(candidate_guides)){
    guide_strand <- as.character(candidate_guides[g]@strand)
    guide_pam_site <- candidate_guides[g]$pam_site
    current_guide_warning <- ""
    
    if (guide_strand == "+") {
      edit_window_genomic_start <- guide_pam_site + edit_min_off 
      edit_window_genomic_end <- guide_pam_site + edit_max_off
    } else {
      edit_window_genomic_start <- guide_pam_site - edit_max_off
      edit_window_genomic_end <- guide_pam_site - edit_min_off
    }
    
    if (strand == "+") {
      idx <- which(flanking_abs_coordinates >= edit_window_genomic_start)
      idx2 <- which(flanking_abs_coordinates <= edit_window_genomic_end)
      
      first_base_pos <- if(length(idx) > 0) idx[1] else 1
      last_base_pos <- if(length(idx2) > 0) idx2[length(idx2)] else 1
      
    } else {
      idx <- which(flanking_abs_coordinates >= edit_window_genomic_start) #Same >= because coordinates are returned in decreasing order for the negative strand
      idx2 <- which(flanking_abs_coordinates >= edit_window_genomic_end)
      
      #THEY ARE INVERTED HERE BECAUSE THEY ARE INDICES AND THEY RUN IN THE OPPOSITE DIRECTION
      #last_base_pos MUST be smaller than first_base_pos for the remaining code to work as intended
      last_base_pos <- if(length(idx) > 0) idx[length(idx)] else 1
      first_base_pos <- if(length(idx2) > 0) idx2[length(idx2)] else 1 #Subtract because last_base_pos is an index on flanking_abs_coordinates, which is returned in the reverse order for the negative strand
    }
    
    #last_base_pos <- first_base_pos + editing_window_length #BUG? YES. Strand dependent
    
    #if (first_base_pos < 1) first_base_pos <- 1
    if (last_base_pos > nchar(flanking_dna_seq)) last_base_pos <- nchar(flanking_dna_seq)
    
    #spans <- spansIntron(flanking_abs_coordinates, first_base_pos, last_base_pos, absolute_codon_locations)
    #spansIntron() not necessary anymore because first_base_pos and last_base_pos trim the positions accordingly
    #to know if they span an intron-exon junction, just check the length of the editing window on the exons
    
    spans <- abs(first_base_pos-last_base_pos + 1) < editing_window_length
    
    #if (spans) {
    #  current_guide_warning <- "Edit window spans intron-exon junction."
    #}
    
    if (strand == guide_strand) {
      match_pat <- as.character(target_letter)
      replace_pat <- as.character(new_letter)
    } else {
      match_pat <- as.character(complement(target_letter))
      replace_pat <- as.character(complement(new_letter))
    }
    
    # 6. Create Mutant Sequence
    # We substitute ONLY within the clipped boundaries
    edited_region <- gsub(match_pat, replace_pat, substr(flanking_dna_seq, first_base_pos, last_base_pos))
    unedited_left <- substr(flanking_dna_seq, 1, first_base_pos - 1)
    unedited_right <- substr(flanking_dna_seq, last_base_pos + 1, nchar(flanking_dna_seq))
    
    mutant_dna <- DNAString(paste0(unedited_left, edited_region, unedited_right))
    mutant_flanking_protein <- as.character(translate(mutant_dna, genetic.code = GENETIC_CODE, no.init.codon = TRUE))
    
    # 7. Construct Display Output
    # We use 'ceiling' to find the codon indices containing the start and end of the edit
    edit_start_codon <- ceiling(first_base_pos / 3)
    edit_end_codon   <- ceiling(last_base_pos / 3)
    
    # Calculate how many AAs are purely to the left and purely to the right of the edit
    num_aa_left  <- max(0, edit_start_codon - 1)
    num_aa_right <- max(0, nchar(mutant_flanking_protein) - edit_end_codon)
    
    format_output <- function(prot_seq, left, right, miss_start, miss_end) {
      # The mid_part is the segment being highlighted with pipes | |
      # It covers from the start codon of the edit to the end codon of the edit
      mid_part <- substr(prot_seq, left + 1, nchar(prot_seq) - right)
      
      paste0(paste0(rep("-", miss_start), collapse=""),
             substr(prot_seq, 1, left), "|", mid_part, "|",
             substr(prot_seq, nchar(prot_seq) - right + 1, nchar(prot_seq)),
             paste0(rep("-", miss_end), collapse=""))
    }
    
    wildtype_aa_seqs <- c(wildtype_aa_seqs, format_output(wildtype_flanking_protein, num_aa_left, num_aa_right, missing_aa_start, missing_aa_end))
    mutant_aa_seqs <- c(mutant_aa_seqs, format_output(mutant_flanking_protein, num_aa_left, num_aa_right, missing_aa_start, missing_aa_end))
    warnings <- c(warnings, current_guide_warning)
  }
  
  return(list(wildtype_seqs = wildtype_aa_seqs, mutant_seqs = mutant_aa_seqs, warnings = warnings))
}