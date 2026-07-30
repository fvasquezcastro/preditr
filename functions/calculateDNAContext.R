calculateDNAContext <- function(genome, chromosome, pam_site, strand, editing_window, context_len = 50){
  #Derives genomic edit-window bounds using the same formula as flagGuides.R,
  #then extracts dna_edit_window plus the context_len-nt flanks immediately
  #upstream/downstream of it. Biostrings::getSeq reverse-complements for "-"
  #strand ranges, so results come back in the guide's own 5'->3' orientation
  #(same convention as protospacer_seq). Vectorized: one row builder can call
  #it once for a whole GuideSet (addNEC.R) or once per guide (generatePartialOutput.R).
  pam_site <- as.numeric(pam_site)
  is_plus <- as.character(strand) == "+"

  edit_window_lower <- ifelse(is_plus, pam_site - max(abs(editing_window)), pam_site + min(abs(editing_window)))
  edit_window_upper <- ifelse(is_plus, pam_site - min(abs(editing_window)), pam_site + max(abs(editing_window)))

  upstream_start   <- ifelse(is_plus, edit_window_lower - context_len, edit_window_upper + 1)
  upstream_end     <- ifelse(is_plus, edit_window_lower - 1, edit_window_upper + context_len)
  downstream_start <- ifelse(is_plus, edit_window_upper + 1, edit_window_lower - context_len)
  downstream_end   <- ifelse(is_plus, edit_window_upper + context_len, edit_window_lower - 1)

  seqlens <- GenomeInfoDb::seqlengths(genome)[as.character(chromosome)]
  clamp <- function(starts, ends) list(start = pmax(1, starts), end = pmin(seqlens, ends))

  fetch <- function(bounds){
    seqs <- rep("", length(chromosome))
    valid <- bounds$start <= bounds$end

    if (any(valid)){

      gr <- GenomicRanges::GRanges(
        seqnames = chromosome[valid],
        ranges = IRanges::IRanges(start = bounds$start[valid], end = bounds$end[valid]),
        strand = strand[valid]
      )

      seqs[valid] <- as.character(Biostrings::getSeq(genome, gr))
    }

    seqs
  }

  return(list(
    dna_edit_window        = fetch(clamp(edit_window_lower, edit_window_upper)),
    dna_context_upstream   = fetch(clamp(upstream_start, upstream_end)),
    dna_context_downstream = fetch(clamp(downstream_start, downstream_end))
  ))
}
