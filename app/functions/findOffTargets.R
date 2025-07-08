findOffTargets <- function(results, genome, indexed_genome, n_mismatches, n_max_alignments, txdb){
  
  
  ebwt_files <- list.files(indexed_genome, pattern = "\\.ebwt$", full.names = FALSE)
  prefixes <- sub("\\..*$", "", ebwt_files)
  
  if (length(unique(prefixes)) != 1){
    
    logError("The path to the indexed genome does not point to one.")
    stop()
    
  }
  
  indexed_genome_path <- file.path(indexed_genome, prefixes[1])
  
  partial_guideset <- lapply(results, function(x) x$partial_guideset)
  partial_guideset <- Filter(Negate(is.null), partial_guideset) #Exclude the NULLs from unexpected errors, if any
  
  guideSet <- do.call(c, partial_guideset)
  
  col_names <- paste0("alignments_n", 0:n_mismatches)
  all_col_names <- c("row_num", col_names)
  offtargets <- data.frame(matrix(ncol = length(all_col_names), nrow = length(guideSet)))
  colnames(offtargets) <- all_col_names
  
  if (length(guideSet) == 0){
    
    return(offtargets)
  }
  
  names(guideSet) <- 1:length(names(guideSet)) #Needed for duplicated guides. addSpacerAlignments throws an error in that case
  
  suppressWarnings(
    guideSet <- addSpacerAlignments(guideSet,
                                    txObject=txdb, 
                                    aligner_index=indexed_genome_path,
                                    bsgenome=genome,
                                    n_mismatches=n_mismatches,
                                    n_max_alignments=n_max_alignments)
  )

  offtargets$row_num <- as.vector(guideSet$row_num)
  
  #Fill out alignments columns
  for (m in 0:n_mismatches){
    
    col_name <- paste0("alignments_n", m)
    c <- paste0("n", m)
    
    offtargets[[col_name]] <- as.character(mcols(guideSet)[[c]])
    
  }
  
  return (offtargets)
}