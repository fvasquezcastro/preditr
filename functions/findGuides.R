findGuides <- function(cds_coordinates, genome, txdb, editor, absolute_codon_locations, 
                       target_aa, edit_type, codon_seq, strand){
  
  
  #ensembl_id <- cds_coordinates@elementMetadata$tx_id[1]
  
  #introns_coordinates <- queryTxObject(txObject=txdb,
  #                                     featureType="introns",
  #                                     queryColumn="tx_id",
  #                                     queryValue=ensembl_id)
  
  #A few genes are an exon only
  #if (length(introns_coordinates) > 0){
  #  names(introns_coordinates) <- paste0(names(introns_coordinates), "_intron")
  #}
  
  
  #exons_coordinates <- queryTxObject(txObject=txdb, 
  #                                     featureType="exons",
  #                                     queryColumn="tx_id",
  #                                     queryValue=ensembl_id)
  
  #names(exons_coordinates) <- paste0(names(exons_coordinates), "_exon")
  
  #all_coordinates <- c(introns_coordinates, exons_coordinates)
  
  #regions_of_interest <- findRegionsOfInterest(all_coordinates, codon_absolute_locations, editor) #To design guides only around the region of interest and not the entire gene
  
  #coordinates_of_interest <- all_coordinates[names(all_coordinates) %in% regions_of_interest, ]
  
  spacer_length <- as.numeric(get(editor)@spacer_length)
  range <- IRanges(start=min(absolute_codon_locations)-spacer_length,
                  end=max(absolute_codon_locations)+spacer_length)
  
  granges <- GRanges(seqnames = as.character(cds_coordinates@seqnames)[1], ranges = range,
                     strand = as(strand, "Rle"), seqinfo = NULL, seqlengths = NULL)
  
  
  guides <- findSpacers(granges, 
                        bsgenome = genome,
                        crisprNuclease = get(editor))
  
  guides <- addSequenceFeatures(guides)
  
  candidate_rows <- c()
  
  pam_ranges <- calculatePAMRange(target_aa, editor, edit_type, absolute_codon_locations, codon_seq, strand)
  
  
  if ((length(pam_ranges$current_strand_ranges) == 0) & (length(pam_ranges$opposite_strand_ranges) == 0)) {
    return(character(0)) #If returning empty candidate_rows, it will be a NULL and generatePartialOutput() misinterprets a NULL here
    }
  
  
  if (strand == "+"){
    
    if (length(pam_ranges$current_strand_ranges) > 0) {
      for (i in seq(1, length(pam_ranges$current_strand_ranges), by = 2)){ #Iterating with a step of 2 because all ranges values are in the same vector one after the other. Every odd number n is the minimum while n+1 is the maximum of a range.
      
      min_coordinate <- pam_ranges$current_strand_ranges[i]
      max_coordinate <- pam_ranges$current_strand_ranges[i+1]

      new_candidates <- which((guides@strand == "+" & guides$pam_site <= max_coordinate & guides$pam_site >= min_coordinate))

      candidate_rows <- c(candidate_rows, new_candidates)
      
      }
      
    } 
    
    if (length(pam_ranges$opposite_strand_ranges) > 0) {
      
      for (i in seq(1, length(pam_ranges$opposite_strand_ranges), by = 2)){
        
        min_coordinate <- pam_ranges$opposite_strand_ranges[i]
        max_coordinate <- pam_ranges$opposite_strand_ranges[i+1]
        
        new_candidates <- which((guides@strand == "-" & guides$pam_site <= max_coordinate & guides$pam_site >= min_coordinate))
        candidate_rows <- c(candidate_rows, new_candidates)
        
        
      }
      
    }
    
  }
  
  if (strand == "-"){
    
    
    if (length(pam_ranges$current_strand_ranges) > 0) {
      for (i in seq(1, length(pam_ranges$current_strand_ranges), by = 2)){ #Iterating with a step of 2 because all ranges values are in the same vector one after the other. Every odd number n is the minimum while n+1 is the maximum of a range.
        
        min_coordinate <- pam_ranges$current_strand_ranges[i]
        max_coordinate <- pam_ranges$current_strand_ranges[i+1]
        
        new_candidates <- which((guides@strand == "-" & guides$pam_site <= max_coordinate & guides$pam_site >= min_coordinate))
        candidate_rows <- c(candidate_rows, new_candidates)
        
      }
    }
    
    
    if (length(pam_ranges$opposite_strand_ranges) > 0) {
      
      for (i in seq(1, length(pam_ranges$opposite_strand_ranges), by = 2)){
        
        min_coordinate <- pam_ranges$opposite_strand_ranges[i]
        max_coordinate <- pam_ranges$opposite_strand_ranges[i+1]
        
        new_candidates <- which((guides@strand == "+" & guides$pam_site <= max_coordinate & guides$pam_site >= min_coordinate))
        candidate_rows <- c(candidate_rows, new_candidates)
        
        
      }
      
    }
    
  }
  
  
  candidate_guides <- guides[unique(candidate_rows)] #Only the guides whose PAM site is located within the optimal edit range to target the desired codon in the desired base

  return(candidate_guides)
}