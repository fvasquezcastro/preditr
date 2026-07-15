calculateGuideCoordinates <- function(pam_site, strand, spacer_len, pam_len){
  #Derives genomic start/end for the PAM and the protospacer from the pam_site.
  #Editors are always built with pam_side = "3prime" (see createEditor.R), so the
  #protospacer sits 5' of the PAM. crisprBase reports pam_site as the first PAM
  #nucleotide with respect to the protospacer strand:
  #  + strand guide: protospacer [P - S, P - 1], PAM [P, P + L - 1]
  #  - strand guide: protospacer [P + 1, P + S], PAM [P - L + 1, P]
  #Coordinates are returned in genomic orientation (start <= end) regardless of strand.
  #This mirrors crisprBase::getProtospacerRanges()/getPamRanges() for the spacer_gap = 0
  #case, which holds for every PrEditR editor (createEditor.R builds nucleases without a
  #spacer gap). If a gapped nuclease is ever introduced, delegate to those crisprBase
  #functions instead.
  #Vectorized (ifelse) so it accepts a single guide or a whole GuideSet's columns.
  pam_site <- as.numeric(pam_site)
  spacer_len <- as.numeric(spacer_len)
  pam_len <- as.numeric(pam_len)

  is_plus <- as.character(strand) == "+"

  protospacer_start <- ifelse(is_plus, pam_site - spacer_len, pam_site + 1)
  protospacer_end <- ifelse(is_plus, pam_site - 1, pam_site + spacer_len)
  pam_start <- ifelse(is_plus, pam_site, pam_site - pam_len + 1)
  pam_end <- ifelse(is_plus, pam_site + pam_len - 1, pam_site)

  return(list(
    pam_start = pam_start,
    pam_end = pam_end,
    protospacer_start = protospacer_start,
    protospacer_end = protospacer_end
  ))
}
