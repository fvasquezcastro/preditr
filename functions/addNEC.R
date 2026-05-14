addNEC <- function(output, editors_path, non_targeting_controls, flanking5, flanking3,
                   off_targets, genome, indexed_genome, n_mismatches, n_max_alignments,
                   txdb){
  
  unique_editors <- unique(as.vector(output$editor))
  loadEditors(editors_path, unique_editors)
  
  #An empty GuideSet object is needed
  dummy_seq <- Biostrings::DNAStringSet("AAAAAAAAAAAAAAAAAAAAAAAAAAA")
  all_nec_guides <- crisprDesign::findSpacers(dummy_seq, bsgenome = NULL, crisprNuclease = crisprBase::SpCas9)
  S4Vectors::mcols(all_nec_guides) <- cbind(
    S4Vectors::mcols(all_nec_guides),
    S4Vectors::DataFrame(
      editor      = character(0),
      edit_type   = character(0),
      gene_symbol = character(0),
      ensembl_id  = character(0),
      gene_strand = character(0),
      chromosome  = character(0),
      intron_exon = character(0)
    )
  )
  
  
  for (e in unique_editors){
    
    all_editor_guides <- crisprDesign::findSpacers(dummy_seq, bsgenome = NULL, crisprNuclease = crisprBase::SpCas9)
    S4Vectors::mcols(all_editor_guides) <- cbind(
      S4Vectors::mcols(all_editor_guides),
      DataFrame(
        editor      = character(0),
        edit_type   = character(0),
        gene_symbol = character(0),
        ensembl_id  = character(0),
        gene_strand = character(0),
        chromosome  = character(0),
        intron_exon = character(0)
      )
    )
    
    transcript_ids <- unique(as.vector(output[output$editor == e, ]$ensembl_id))
    edit_type <- unique(as.vector(output[output$editor == e, ]$edit_type))
      
    
    for (t in transcript_ids){
      
      for (r in c("exons", "introns")) {
        
        
        t_coordinates <- crisprDesign::queryTxObject(txObject=txdb, 
                                       featureType=r,
                                       queryColumn="tx_id",
                                       queryValue=t)
        
        t_guides <- crisprDesign::findSpacers(t_coordinates, 
                                bsgenome = genome,
                                crisprNuclease = get(e))
        
        t_guides <- crisprDesign::addSequenceFeatures(t_guides)
        
        if (length(t_guides) > 0){ #They have to be renamed to avoid conflicts
          names(t_guides) <- paste0(names(t_guides), "_", e, "_", t, "_", r)
          
          t_guides$editor <- e
          t_guides$edit_type <- edit_type
          t_guides$gene_symbol <- t_coordinates$gene_symbol[1]
          t_guides$ensembl_id <- t
          t_guides$gene_strand <- as.character(t_coordinates@strand[1])
          t_guides$chromosome <- as.character(t_coordinates@seqnames[1])
          t_guides$intron_exon <- r
          
          suppressWarnings(
            all_editor_guides <- c(all_editor_guides, t_guides)
          )
          
        }
        
      }
        
    }
      
    
    #Get the editing window 
    editing_weights_matrix <- get(e)@editingWeights
    editing_weights <- editing_weights_matrix[toupper(edit_type),]
    editing_window_indices <- c(which(editing_weights != 0)[1], 
                                tail(which(editing_weights != 0), 1))
    
    editing_window <- c(as.numeric(colnames(editing_weights_matrix))[editing_window_indices[1]], 
                        as.numeric(colnames(editing_weights_matrix))[editing_window_indices[2]])
    
    target_letter <- toupper(substr(edit_type, 1,1))
    
    spacer_len <- get(e)@spacer_length
    
    keep_bool <- mapply(
      isNEC,
      as.character(all_editor_guides$protospacer),
      MoreArgs = list(target_base = toupper(substr(edit_type, 1,1)),
                      editing_window = editing_window,
                      spacer_len = spacer_len)
    )
    
    nec_guides <- all_editor_guides[unname(keep_bool)]
    
    if (length(nec_guides) >0 ){
      
      suppressWarnings(
        
        all_nec_guides <- c(all_nec_guides, nec_guides)
      )
      
    }

  }
  
  all_nec_guides <- scoreGuides(all_nec_guides, flanking5, flanking3)
  
  #Off-target searches for NEC are not performed because it no matter where it aligns in the genome, they will not make edits
  #if (off_targets){
    
    #suppressWarnings(
      #all_nec_guides <- addSpacerAlignments(all_nec_guides,
                                            #txObject=txdb, 
                                            #aligner_index=indexed_genome_path,
                                            #bsgenome=genome,
                                            #n_mismatches=n_mismatches,
                                            #n_max_alignments=n_max_alignments)
    #)
    
  #}
  
  
  # Combine everything into a data frame containing ONLY not-targeting guides
  nec_df <- data.frame(
    query_num = rep("", length(all_nec_guides)),
    gene_symbol = as.character(all_nec_guides$gene_symbol),
    ensembl_id = as.character(all_nec_guides$ensembl_id),
    uniprot_id = rep("", length(all_nec_guides)), #Will be added when it goes back to generateOutput() for the entire table at once
    target_aa = rep("", length(all_nec_guides)),
    target_position = rep("", length(all_nec_guides)),
    editor = as.character(all_nec_guides$editor),
    edit_type = as.character(all_nec_guides$edit_type),
    gene_strand = as.character(all_nec_guides$gene_strand),
    protospacer_seq = as.character(all_nec_guides$protospacer),
    percent_gc = as.character(all_nec_guides$percentGC),
    protospacer_strand = as.character(BiocGenerics::strand(all_nec_guides)),
    pam_seq = as.character(all_nec_guides$pam),
    chromosome = as.character(BiocGenerics::seqnames(all_nec_guides)),
    pam_coordinates = as.character(all_nec_guides$pam_site),
    mutation_type = paste0("not_editing_", all_nec_guides$intron_exon),
    wildtype_sequence = rep("", length(all_nec_guides)),
    mutant_sequence = rep("", length(all_nec_guides)),
    edits = rep("", length(all_nec_guides)),
    warnings = rep("", length(all_nec_guides)),
    error = "",
    EcoRI = as.character(all_nec_guides$enzymeAnnotation[, "EcoRI"]),
    KpnI = as.character(all_nec_guides$enzymeAnnotation[, "KpnI"]),
    BsmBI = as.character(all_nec_guides$enzymeAnnotation[, "BsmBI"]),
    BsaI = as.character(all_nec_guides$enzymeAnnotation[, "BsaI"]),
    BbsI = as.character(all_nec_guides$enzymeAnnotation[, "BbsI"]),
    PacI = as.character(all_nec_guides$enzymeAnnotation[, "PacI"]),
    MluI = as.character(all_nec_guides$enzymeAnnotation[, "MluI"]),
    stringsAsFactors = FALSE
  )
  
  #Just to fill out the columns so that the binding to the output that contains them does not throw an error
  #The columns for the alignments are ONLY included in the output if there are guides. If no guide was found and output_df only
  #contains rows without protospacers, the columns will not be there
  if (off_targets){
    
    for (m in 0:n_mismatches){
      
      col_name <- paste0("alignments_n", m)
      
      if (col_name %in% colnames(output)){
        nec_df[[col_name]] <- rep("", length(all_nec_guides))
      }
      
      
    }
    
  }

  return(rbind(output, nec_df))
  
}