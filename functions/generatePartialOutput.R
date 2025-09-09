generatePartialOutput <- function(row_num, candidate_guides, genome, target_position, target_aa,
                                  cds_coordinates, strand, editor, edit_type, gene_symbol, 
                                  ensembl_id, flags){
  #Have to take notes of the guides that were skipped to not export them in the partial guideset
  excluded_guides <- c()
  
  if (!is.null(candidate_guides) & (length(candidate_guides) > 0)){
     
    #Remove non-targeting guides
    candidate_guides <- candidate_guides[candidate_guides$maxVariant != "not_targeting"]
  }

  if (length(candidate_guides) == 0 | typeof(candidate_guides) == "NULL"){
    
    if (length(candidate_guides) == 0){
      
      new_row <- data.frame(query_num = as.character(row_num),
                            gene_symbol_used = gene_symbol,
                            ensembl_id_used = ensembl_id,
                            gene_strand = "",
                            protospacer_seq = "No guides found",
                            percent_gc = "",
                            protospacer_strand = "",
                            pam_seq = "",
                            chromosome = "",
                            pam_coordinates = "",
                            mutation_type = "",
                            wildtype_sequence = "",
                            mutant_sequence = "",
                            edits = "")
    }
    
    if (typeof(candidate_guides) == "NULL") {
      
      new_row <- data.frame(query_num = as.character(row_num),
                            gene_symbol_used = gene_symbol,
                            ensembl_id_used = "",
                            gene_strand = "",
                            protospacer_seq = "Amino acid not found at the position indicated or gene does not exist in the database (check the log file for details)",
                            percent_gc = "",
                            protospacer_strand = "",
                            pam_seq = "",
                            chromosome = "",
                            pam_coordinates = "",
                            mutation_type = "",
                            wildtype_sequence = "",
                            mutant_sequence = "",
                            edits = "")
    }
    

      enzymes <- data.frame(
        EcoRI = "",
        KpnI = "",
        BsmBI = "",
        BsaI = "",
        BbsI = "",
        PacI = "", 
        MluI = ""
      )
      
      new_row <- cbind(new_row, enzymes)
      partial_df <- new_row

    
  } else {
    
    #Tag each guide with the appropriate row for the off-target search and final merging
    candidate_guides$query_num <- rep(row_num, length(candidate_guides))
    
    candidate_guides <- candidate_guides[order(candidate_guides$pam_site),]
    
    partial_df <- data.frame()
    
    alleles <- editedAlleles(candidate_guides)
    
    if (is.null(alleles)){
      #This means that the annotateEdits() function returned early
      sequences <- list(wildtype_seqs = rep("Unable to generate. Please check manually.", times = length(candidate_guides)),
                        mutant_seqs = rep("Unable to generate. Please check manually.", times = length(candidate_guides)))
    } else {
      
      sequences <- generateWindowSeqs(genome, cds_coordinates, target_position, strand, candidate_guides,
                                      alleles[alleles$score!= 0,], editor, edit_type, flags)
      
      edits <- summarizeEdits(sequences, target_position)
    }
    
    #Add something in case the candidate guides list only contains one and is skipped. It would crash and the line
    #would be omitted from the output

    for (i in 1:length(candidate_guides)){
    skip <- FALSE
    
      if (!is.null(alleles)){
        if (sequences$wildtype_seqs[i] == "SKIP" & sequences$mutant_seqs[i] == "SKIP"){
          #excluded_guides <- c(excluded_guides, i)
          skip <- TRUE
          wt_sequence <- "Please check manually"
          mut_sequence <- "Please check manually"
          guide_edit <- paste0(target_aa, target_position, sub(".*?(.)\\1+.*", "\\1",alleles[alleles$score == 1, ]$aa[i]))
          #next
          }
      }
        
      
      new_row <- data.frame(query_num = as.character(row_num),
                            gene_symbol_used = gene_symbol,
                            ensembl_id_used = ensembl_id,
                            gene_strand = strand,
                            protospacer_seq = as.character(candidate_guides[i]$protospacer),
                            percent_gc = as.character(candidate_guides[i]$percentGC),
                            protospacer_strand = as.character(candidate_guides[i]@strand),
                            pam_seq = as.character(candidate_guides[i]$pam),
                            chromosome = as.character(candidate_guides[i]@seqnames[1]),
                            pam_coordinates = as.character(candidate_guides[i]$pam_site),
                            mutation_type = ifelse(is.null(candidate_guides[i]$maxVariant), "Undetermined", candidate_guides[i]$maxVariant), #This is for those cases that skipped the annotateEdits() part
                            wildtype_sequence = ifelse(skip, wt_sequence, sequences$wildtype_seqs[i]),
                            mutant_sequence = ifelse(skip, mut_sequence, sequences$mutant_seqs[i]),
                            edits = ifelse(skip, guide_edit, ifelse(is.null(edits[i]), "", edits[i])))
      
        enzymes <- data.frame(
          EcoRI = candidate_guides$enzymeAnnotation[i, "EcoRI"][[1]],
          KpnI = candidate_guides$enzymeAnnotation[i, "KpnI"][[1]],
          BsmBI = candidate_guides$enzymeAnnotation[i, "BsmBI"][[1]],
          BsaI = candidate_guides$enzymeAnnotation[i, "BsaI"][[1]],
          BbsI = candidate_guides$enzymeAnnotation[i, "BbsI"][[1]],
          PacI = candidate_guides$enzymeAnnotation[i, "PacI"][[1]], 
          MluI = candidate_guides$enzymeAnnotation[i, "MluI"][[1]]
        )
        
        enzymes[] <- lapply(enzymes, as.character)
        
        new_row <- cbind(new_row, enzymes)
      
      partial_df <- rbind(partial_df, new_row)

    }
  }
  
  partial_output <- list(
    partial_df = partial_df,
    partial_guideset = candidate_guides #candidate_guides[!(seq_along(candidate_guides) %in% excluded_guides)]
  )
  
  return(partial_output)
  
}