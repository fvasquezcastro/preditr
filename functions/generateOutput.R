generateOutput <- function(df, job_name, output_path, results, offtargets_df, off_targets,
                           organism, editors_path, non_targeting_controls, flanking5, flaking3,
                           genome, indexed_genome, n_mismatches, n_max_alignments, txdb){
  
  #Results comes with the logs too
  
  results2 <- lapply(results, function(x) x$partial_df)
  
  results3 <- purrr::keep(results2, ~inherits(.x, "data.frame")) #Errors are included because they produce a df via generateErrorOutput
  
  partial_output <- dplyr::bind_rows(results3)
  
  if (off_targets){
    
    partial_output_not_found <- partial_output[partial_output$mutation_type == "", ] #Not found and error rows
    partial_output_found <- partial_output[partial_output$mutation_type != "", ]
    
    if (nrow(partial_output_found) != 0){
      #If here, the output will NOT contain the columns for the alignments. No guides were found, so they are irrelevant
      partial_output_found <- cbind(partial_output_found, offtargets_df[, -1])
    }
    
    
    if (nrow(partial_output_not_found) > 0){
      
      missing_cols <- colnames(partial_output_found)[!(colnames(partial_output_found) %in% colnames(partial_output_not_found))]
      
      for (col in missing_cols){
        
        partial_output_not_found[[col]] <- ""
      }
      
      partial_output <- rbind(partial_output_found, partial_output_not_found)
      
    } else {
      
      partial_output <- partial_output_found
    }
    

    partial_output <- partial_output[order(partial_output$query_num), ]
  }
  
  output <- merge(df, partial_output, by="query_num", all.y = TRUE)
  
  merged_ensembl_id <- ifelse(nzchar(output$ensembl_id_used),
                              output$ensembl_id_used, 
                              output$ensembl_id)
  
  merged_gene_symbol <- ifelse(nzchar(output$gene_symbol_used),
                               output$gene_symbol_used, 
                               output$gene_symbol)
  
  output$ensembl_id <- merged_ensembl_id
  output$gene_symbol <- merged_gene_symbol
  
  output$ensembl_id_used <- NULL
  output$gene_symbol_used <- NULL
  
  output[] <- lapply(output, as.character)
  output[is.na(output)] <- ""
  
  if (non_targeting_controls){
    
    output <- addNTC(output, editors_path, non_targeting_controls, flanking5, flanking3,
                     off_targets, genome, indexed_genome, n_mismatches, n_max_alignments, txdb)
    
  }
    
  write.csv(output, file = file.path(output_path, paste0(job_name, "_results", ".csv")), row.names = FALSE)
    
}