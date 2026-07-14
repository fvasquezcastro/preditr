#Scores amino-acid substitutions using the BLOSUM62 matrix (shipped with Biostrings).
#Input `edits` is the comma-separated string produced by summarizeEdits(), e.g. "H42Y, A45G".
#Each token is <wildtype aa><position><mutant aa>; nonsense edits carry a "*" as the mutant.
#Returns a comma-separated string of scores aligned to the edits, or "" when there are no edits.

scoreBLOSUM <- function(edits) {

  if (is.na(edits) || !nzchar(edits)) {
    return("")
  }

  #BLOSUM62 is a built-in dataset; load it into this function's environment only.
  utils::data("BLOSUM62", package = "Biostrings", envir = environment())
  blosum <- get("BLOSUM62", envir = environment())

  tokens <- trimws(strsplit(edits, ",")[[1]])
  tokens <- tokens[nzchar(tokens)]

  scores <- vapply(tokens, function(tok) {

    wildtype_aa <- substr(tok, 1, 1)
    mutant_aa   <- substr(tok, nchar(tok), nchar(tok))

    if (wildtype_aa %in% rownames(blosum) && mutant_aa %in% colnames(blosum)) {
      as.character(blosum[wildtype_aa, mutant_aa])
    } else {
      NA_character_
    }

  }, character(1))

  paste(scores, collapse = ", ")
}
