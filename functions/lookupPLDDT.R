#Looks up AlphaFold per-residue pLDDT confidence for each amino-acid position in an edits string.
#
#The pLDDT map ships in the per-organism reference image, not the app image (see
#references/docs/compose-reference-images.md). It is resolved in this order:
#  1. <PREDITR_REFERENCES_PATH>/<organism>/maps/plddt.rds  (compose: /refs, populated by the ref image)
#  2. maps/<organism>/plddt.rds                            (host CLI / local dev, and where build_plddt_map.R writes)
#The env var is read directly (not via global.R's references_path) so the lookup works in both the
#CLI and Shiny entry points. When no map is found (feature not provisioned for this organism), every
#lookup returns "" so existing runs keep working unchanged.
#
#The map is a named list keyed by canonical UniProt accession -> numeric vector of per-residue pLDDT
#(index = residue number). Build it with maps/build_plddt_map.R.
#
#`edits`      is the comma-separated string from summarizeEdits(), e.g. "H42Y, A45G".
#`uniprot_id` is the accession for the row (isoform suffixes like "-2" are stripped before lookup).
#Returns a comma-separated string of pLDDT values aligned to the edits, or "" when there is nothing to score.

#Resolve the plddt.rds path for an organism, preferring the reference volume over the baked-in maps dir.
resolvePLDDTPath <- function(organism) {

  ref_base <- Sys.getenv("PREDITR_REFERENCES_PATH", unset = "")
  if (nzchar(ref_base)) {
    ref_path <- file.path(ref_base, organism, "maps", "plddt.rds")
    if (file.exists(ref_path)) {
      return(ref_path)
    }
  }

  local_path <- file.path("maps", organism, "plddt.rds")
  if (file.exists(local_path)) {
    return(local_path)
  }

  NA_character_
}

#Cache the loaded map per organism so we do not read the (potentially large) rds once per output row.
.plddt_cache <- new.env(parent = emptyenv())

loadPLDDTMap <- function(organism) {

  if (exists(organism, envir = .plddt_cache, inherits = FALSE)) {
    return(get(organism, envir = .plddt_cache, inherits = FALSE))
  }

  map_path <- resolvePLDDTPath(organism)

  plddt_map <- if (!is.na(map_path)) readRDS(map_path) else NULL

  assign(organism, plddt_map, envir = .plddt_cache)
  plddt_map
}

lookupPLDDT <- function(edits, uniprot_id, organism) {

  if (is.na(edits) || !nzchar(edits)) {
    return("")
  }

  plddt_map <- loadPLDDTMap(organism)

  if (is.null(plddt_map) || is.na(uniprot_id) || !nzchar(uniprot_id)) {
    return("")
  }

  #AlphaFold DB keys on the canonical accession; drop any "-N" isoform suffix.
  accession <- sub("-[0-9]+$", "", uniprot_id)
  residue_scores <- plddt_map[[accession]]

  if (is.null(residue_scores)) {
    return("")
  }

  tokens <- trimws(strsplit(edits, ",")[[1]])
  tokens <- tokens[nzchar(tokens)]

  scores <- vapply(tokens, function(tok) {

    position <- suppressWarnings(as.integer(gsub("[^0-9]", "", tok)))

    if (is.na(position) || position < 1 || position > length(residue_scores)) {
      NA_character_
    } else {
      as.character(round(residue_scores[position], 1))
    }

  }, character(1))

  paste(scores, collapse = ", ")
}
