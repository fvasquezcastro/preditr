findACLbyID <- function(genome, txdb, ensembl_id, target_position, target_aa){
  
  
  output1 <- findPotentialACL(genome, ensembl_id, target_position, txdb)
  
  
  if (is.null(output1)){
    
    return(NULL)
  }
  
  potentialACL <- output1$potentialACL
  cds_coordinates <- output1$cds_coordinates
  strand <- output1$strand
  gene_symbol <- output1$gene_symbol
  #current_region <- output1$current_region
  
  codon_seq <- checkCodonLocations(genome, ensembl_id, target_position, target_aa, cds_coordinates, potentialACL, strand)
  
  if (is.null(codon_seq)){ #For any of the two errors that are included in checkCodonLocations()

    return(NULL)
  }
  
  return(list(
    acl = potentialACL,
    cds_coordinates = cds_coordinates, 
    codon_seq = codon_seq,
    strand=strand,
    #current_region = current_region,
    ensembl_id = ensembl_id,
    gene_symbol = gene_symbol
  )) #Codon_seq will be the sequence in the 5'-3' direction regardless of the strand it is on because that is how it is retrieved with getSeq in checkCodonLocations()
  
  
}