findOffTargets <- function(results, genome, indexed_genome, n_mismatches, n_max_alignments, txdb){
  
  
  ebwt_files <- list.files(indexed_genome, pattern = "\\.ebwt$", full.names = FALSE)
  prefixes <- sub("\\..*$", "", ebwt_files)
  
  if (length(unique(prefixes)) != 1){
    
    logError("The path to the indexed genome does not point to one.")
    stop()
    
  }
  
  indexed_genome_path <- file.path(indexed_genome, prefixes[1])
  
  partial_guideset <- lapply(results, function(x) x$partial_guideset)
  
  # Exclude NULL and character(0), empty guidesets
  partial_guideset <- Filter(function(x) !is.null(x) && length(x) > 0, partial_guideset)
  # Sum the lengths of each element to get the cumulative number of rows
  num_rows <- sum(sapply(partial_guideset, length))
  
  col_names <- paste0("alignments_n", 0:n_mismatches)
  all_col_names <- c("query_num", col_names)
  offtargets <- data.frame(matrix(ncol = length(all_col_names), nrow = num_rows))
  colnames(offtargets) <- all_col_names
  
  if (length(partial_guideset) == 0){
  
    #If partial_guideset is an empty list at this point, an empty df with the necessary query nums must be returned
    #to avoid errors when merging with the output
    offtargets$query_num <- 1:num_rows
    
    for (m in 0:n_mismatches){
      
      col_name <- paste0("alignments_n", m)
      c <- paste0("n", m)
      
      offtargets[[col_name]] <- rep("", num_rows)
      
    }
    
    
    return(offtargets)
  }
  
  guideSet <- do.call(c, partial_guideset)
  guideSet <- as(do.call(c, lapply(partial_guideset, function(x) as(x, "GRanges"))), "GuideSet")
  
  
  names(guideSet) <- 1:length(names(guideSet)) #Needed for duplicated guides. addSpacerAlignments throws an error in that case
  
  suppressWarnings(
    guideSet <- addSpacerAlignments(guideSet,
                                    txObject=txdb, 
                                    aligner_index=indexed_genome_path,
                                    bsgenome=genome,
                                    n_mismatches=n_mismatches,
                                    n_max_alignments=n_max_alignments)
  )

  offtargets$query_num <- as.vector(guideSet$query_num)
  
  #Fill out alignments columns
  for (m in 0:n_mismatches){
    
    col_name <- paste0("alignments_n", m)
    c <- paste0("n", m)
    
    offtargets[[col_name]] <- as.character(mcols(guideSet)[[c]])
    
  }
  
  return (offtargets)
}