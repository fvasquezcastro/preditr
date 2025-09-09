generateEditedCodons <- function(codon_seq, positions, edit_type){
  
  new_char <- toupper(substr(edit_type, 3,3)) #Correct to take into account t2c, which is a2g but in the opposite strand
  
  replace_at_positions <- function(string, positions, new_char) {
    chars <- unlist(strsplit(string, ""))
    chars[positions] <- new_char
    paste(chars, collapse = "")
  }
  
  
  combinations <- list()
  for (k in 1:length(positions)) {
    combinations <- c(combinations, combinations(n=length(positions), r = k, v = positions))
  }
  
  
  variants <- sapply(combinations, replace_at_positions, string = codon_seq, new_char = new_char)
  
  
  unique_variants <- unique(variants)
  
  return(unique_variants)
}