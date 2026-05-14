checkCodonLocations <- function(genome, ensembl_id, target_position,
                                target_aa, cds_coordinates, strand) {

  gene_sequence <- paste0(Biostrings::getSeq(genome, cds_coordinates), collapse="")
  gene_seq_obj <- Biostrings::DNAString(x=gene_sequence, start=1, nchar=NA)
  protein_seq <- Biostrings::translate(gene_seq_obj, genetic.code=Biostrings::GENETIC_CODE, no.init.codon = FALSE)
  
  aa_found_by_position <- Biostrings::letter(protein_seq, target_position)

    if (aa_found_by_position != target_aa){ #This initial part here works for both positive and negative strands because getSeq() returns the sequence in the 5'-3' direction regardless of the cds_coordinates provided
    #logError(paste0("Amino acid not found at the indicated position for transcript ", ensembl_id))

        return(NULL)
    }
  
  codon_seq <- Biostrings::DNAStringSet(substr(gene_sequence, (target_position-1)*3+1, (target_position-1)*3+3))
  
  return(codon_seq)
}
