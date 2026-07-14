#Adds per-mutation metric columns to the final merged output data frame:
#  - blosum_score : BLOSUM62 substitution score(s) for each edit (see scoreBLOSUM.R)
#  - plddt_score  : AlphaFold per-residue pLDDT confidence at each edited position (see lookupPLDDT.R)
#
#Both columns are comma-separated and positionally aligned to the existing `edits` column, so a row
#with edits "H42Y, A45G" yields e.g. blosum_score "-2, 0" and plddt_score "91.3, 88.7".
#Called from generateOutput() on the main process, after df and partial_output are merged (so both
#`edits` and `uniprot_id` are present on every row). Rows with no edits get "".

annotateMetrics <- function(output, organism) {

  if (!("edits" %in% colnames(output)) || nrow(output) == 0) {
    return(output)
  }

  uniprot_ids <- if ("uniprot_id" %in% colnames(output)) output$uniprot_id else rep("", nrow(output))

  output$blosum_score <- vapply(
    output$edits,
    scoreBLOSUM,
    character(1)
  )

  output$plddt_score <- vapply(
    seq_len(nrow(output)),
    function(i) lookupPLDDT(output$edits[i], uniprot_ids[i], organism),
    character(1)
  )

  output
}
