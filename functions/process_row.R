process_row <- function(row_num, gene_symbol, ensembl_id, target_aa, target_position, 
                        editor, edit_type, genome, indexed_genome, organism, txdb, 
                        n_mismatches, n_max_alignments, flanking5, flanking3, tmp_folder){
  
  target_position <- as.numeric(target_position)
  
  location <- findAbsoluteCodonLocation(genome, organism, txdb, gene_symbol, ensembl_id, target_position, target_aa)
  
  if (is.null(location)){
    
    candidate_guides <- NULL
    cds_coordinates <- NULL
    strand <- NULL
    flags <- NULL
    
  } else {
    
    absolute_codon_locations <- location$acl #ACL stands for absolute codon location
    cds_coordinates <- location$cds_coordinates #Contains the coordinates of all the CDSs that belong to that ENSEMBL ID
    codon_seq <- location$codon_seq
    strand <- location$strand
    ensembl_id <- location$ensembl_id #In case it is not provided
    gene_symbol <- location$gene_symbol #In case just ENSEMBL ID is provided
    
    logInfo(paste0("Codon found starting at the genomic coordinate ", absolute_codon_locations[1], " on the ", strand, " strand for transcript ", ensembl_id))
    
    candidate_guides <- findGuides(cds_coordinates, genome, txdb, editor, absolute_codon_locations,
                                   target_aa, edit_type, codon_seq, strand) 
    
    
    if (length(candidate_guides) > 0){
      
      logInfo(paste0("At least one guide was found for row: ", row_num))
      
      candidate_guides <- scoreGuides(candidate_guides, flanking5, flanking3)
      
      candidate_guides <- annotateEdits(candidate_guides, txdb, genome, gene_symbol, editor, edit_type, ensembl_id, cds_coordinates)
      
      suppressWarnings(
        flags <- flagGuides(candidate_guides, cds_coordinates, edit_type, editor, ensembl_id, txdb, genome)
      )
      
    } else {
      
      logInfo(paste0("No guides were found for row: ", row_num))
    }
    
    
  }
  
  partial_output <- generatePartialOutput(row_num, candidate_guides, genome, target_position, target_aa, 
                                          cds_coordinates, strand, editor, edit_type, gene_symbol, 
                                          ensembl_id, flags)
  
  
  return(partial_output)
  
}