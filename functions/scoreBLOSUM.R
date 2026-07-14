#Scores amino-acid substitutions using the BLOSUM62 matrix.
#Input `edits` is the comma-separated string produced by summarizeEdits(), e.g. "H42Y, A45G".
#Each token is <wildtype aa><position><mutant aa>; nonsense edits carry a "*" as the mutant.
#Returns a comma-separated string of scores aligned to the edits, or "" when there are no edits.

#Load the BLOSUM62 matrix. As of Bioconductor 3.19 the substitution matrices moved
#out of Biostrings into the pwalign package; try pwalign first, fall back to
#Biostrings for older environments.
loadBLOSUM62 <- function() {
  for (pkg in c("pwalign", "Biostrings")) {
    if (requireNamespace(pkg, quietly = TRUE)) {
      env <- new.env(parent = emptyenv())
      ok <- tryCatch({
        utils::data("BLOSUM62", package = pkg, envir = env)
        is.matrix(env$BLOSUM62)
      }, warning = function(w) FALSE, error = function(e) FALSE)
      if (isTRUE(ok)) return(env$BLOSUM62)
    }
  }
  stop("BLOSUM62 matrix not available from pwalign or Biostrings.")
}

scoreBLOSUM <- function(edits) {

  if (is.na(edits) || !nzchar(edits)) {
    return("")
  }

  blosum <- loadBLOSUM62()

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
