lookupChromosome <- function(df, organism){
  
  lookup_path <- file.path("bin", organism, "txdb_lookup.rds")
  lookup <- as.data.table(readRDS(lookup_path))
  
  input <- as.data.table(df)
  
  #First match by gene_symbol
  setkey(lookup, gene_symbol)
  
  input[, chr := lookup[input, on = "gene_symbol", mult = "first", chr]]
  
  # Find gene_symbols that did NOT match (but were provided)
  provided_genes <- unique(na.omit(input$gene_symbol))
  matched_genes  <- unique(na.omit(input[!is.na(chr), gene_symbol]))
  unmatched_genes <- setdiff(provided_genes, matched_genes)
  
  if (length(unmatched_genes) > 0) {
    error_message <- sprintf("Error: The following gene_symbol(s) were not found: %s", 
                             paste(unmatched_genes, collapse = ", "))
    logFatal(error_message)
    stop(error_message)
    
  }
  
  #Lookup chromosome by tx_id for rows missing chromosome
  missing_idx <- which(is.na(input$chr) & !is.na(input$ensembl_id))
  
  if (length(missing_idx) > 0) {
    setkey(lookup, tx_id)
    input[missing_idx, chr := lookup[input[missing_idx], on = "tx_id", mult = "first", chr]]
    
    # Check unmatched tx_ids
    provided_tx <- unique(na.omit(input[missing_idx]$ensembl_id))
    matched_tx  <- unique(na.omit(input[missing_idx][!is.na(chr)]$ensembl_id))
    unmatched_tx <- setdiff(provided_tx, matched_tx)
    
    if (length(unmatched_tx) > 0) {
      error_message <- sprintf("Error: The following transcript IDs were not found: %s", 
                               paste(unmatched_tx, collapse = ", "))
      logFatal(error_message)
      stop(error_message)
    }
  }
  
  return(as.data.frame(input))
  
}