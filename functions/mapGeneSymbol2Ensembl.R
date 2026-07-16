mapGeneSymbol2Ensembl <- function(organism, gene_symbol_idx) {

  ParallelLogger::logInfo("Mapping gene symbols to Ensembl IDs...")

  # Normalize input. Gene symbols are matched case-insensitively (human symbols
  # are conventionally upper-case, mouse mixed-case), so both the query and the
  # stored keys are upper-cased before lookup.
  gene_symbol_idx <- ifelse(is.na(gene_symbol_idx) | gene_symbol_idx == "", NA_character_, gene_symbol_idx)

  map_file <- file.path(referenceMapsDir(organism), "symbol_to_ensembl.rds")
  if (!file.exists(map_file)) {
    ParallelLogger::logInfo("No symbol_to_ensembl map for this organism; skipping gene symbol->Ensembl mapping.")
    return(rep(NA_character_, length(gene_symbol_idx)))
  }
  map_env <- readRDS(map_file)

  `%||%` <- function(x, y) if (is.null(x)) y else x

  symbol_to_ensembl <- function(ids) {
    vapply(ids, function(id) {

      if (is.na(id)) {
        NA_character_
      } else {
        map_env[[toupper(id)]] %||% NA_character_
      }

    }, character(1))
  }

  ensembl_idx <- symbol_to_ensembl(gene_symbol_idx)

  ParallelLogger::logInfo("Mapping completed.")

  return(ensembl_idx)
}
