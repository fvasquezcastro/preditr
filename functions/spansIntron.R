spansIntron <- function(flanking_abs_coordinates, first_base_pos, last_base_pos,
                        absolute_codon_locations){
  # This function checks if the edit window spans an intron-exon junction by looking
  # for non-sequential genomic coordinates within the proposed window.
  
  # Ensure indices are within bounds of the coordinate vector to avoid NA crashes
  safe_start <- max(1, first_base_pos)
  safe_end <- min(length(flanking_abs_coordinates), last_base_pos)
  
  if (safe_start >= safe_end) {
    return(list(bool = FALSE, first_base_pos = first_base_pos, last_base_pos = last_base_pos))
  }
  
  edit_window_abs_pos <- flanking_abs_coordinates[safe_start:safe_end]
  bool <- FALSE
  
  # Check genomic coordinate continuity. A difference > 1 means an intron gap.
  for (n in 1:(length(edit_window_abs_pos) - 1)) {
    
    # Safety: Skip if NA values were somehow introduced
    if (is.na(edit_window_abs_pos[n]) || is.na(edit_window_abs_pos[n+1])) next
    
    step <- abs(edit_window_abs_pos[n+1] - edit_window_abs_pos[n])
    
    if (step > 1){ 
      # Spans intron-exon junction.
      bool <- TRUE
      
      # Determine which side of the intron gap contains our target codon middle base
      left_difference <- abs(absolute_codon_locations[2] - edit_window_abs_pos[n])
      right_difference <- abs(absolute_codon_locations[2] - edit_window_abs_pos[n+1])
      
      if (left_difference < right_difference){ 
        # Target codon is on the left side of the intron; clip window to end there
        last_base_pos <- first_base_pos + (n - 1)
      } else {
        # Target codon is on the right side; shift window start to here
        first_base_pos <- first_base_pos + n
      }
      
      return(list(bool = bool, first_base_pos = first_base_pos, last_base_pos = last_base_pos))
    }
  }
  
  return(list(bool = bool, first_base_pos = first_base_pos, last_base_pos = last_base_pos))
}