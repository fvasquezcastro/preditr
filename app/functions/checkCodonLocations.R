checkCodonLocations <- function(genome, ensembl_id, target_position, target_aa, cds_coordinates, codon_absolute_location, strand) {
  
    
    codon_absolute_start <- codon_absolute_location[1]
    codon_absolute_middle <- codon_absolute_location[2]
    codon_absolute_end <- codon_absolute_location[3]


  gene_sequence <- paste0(getSeq(genome, cds_coordinates), collapse="")
  gene_seq_obj <- DNAString(x=gene_sequence, start=1, nchar=NA)
  protein_seq <- translate(gene_seq_obj, genetic.code=GENETIC_CODE, no.init.codon = FALSE)
  
  
  aa_found_by_position <- letter(protein_seq, target_position)

    if (aa_found_by_position != target_aa){ #This initial part here works for both positive and negative strands because getSeq() returns the sequence in the 5'-3' direction regardless of the cds_coordinates provided
    logError(paste0("Amino acid not found at the indicated position for transcript ", ensembl_id))

        return(NULL)
    }
  
  codon_seq <- DNAStringSet(substr(gene_sequence, (target_position-1)*3+1, (target_position-1)*3+3))
  
  return(codon_seq)
}