findCodonLocus <- function(genome, txdb, ensembl_id, target_position, target_aa){
  
  potential_locus <- findPotentialLocus(genome, ensembl_id, target_position, txdb)
  
  if (is.null(potential_locus)){
    
    return(NULL)
  }
  
  potential_coordinates <- potential_locus$potential_coordinates
  cds_coordinates <- potential_locus$cds_coordinates
  strand <- potential_locus$strand
  gene_symbol <- potential_locus$gene_symbol
  #current_region <- potential_locus$current_region
  
  #Make sure it is what it should be
  codon_seq <- checkCodonLocations(genome, ensembl_id, target_position, target_aa, cds_coordinates, strand)
  
  if (is.null(codon_seq)){ #For any of the two errors that are included in checkCodonLocations()
    
    return(NULL)
  }
  
  #If the negative strand is the sense strand, then the codon_seq is given in 5'-3' but the coordinates are retrieved in 3'-5'. They need to be reversed
  #if (strand == "-"){
  #  potential_coordinates <- rev(potential_coordinates)
  #}
  
  return(list(
    absolute_codon_locations = potential_coordinates,
    cds_coordinates = cds_coordinates, 
    codon_seq = codon_seq,
    strand=strand,
    #current_region = current_region,
    ensembl_id = ensembl_id,
    gene_symbol = gene_symbol
  )) #Codon_seq will be the sequence in the 5'-3' direction regardless of the strand it is on because that is how it is retrieved with getSeq in checkCodonLocations()
  
  
  
}