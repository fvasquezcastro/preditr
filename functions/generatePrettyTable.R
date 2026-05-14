generatePrettyTable <- function(results_df, organism, job_name, output_folder){
  
  #Color rows
  results_df$row_color <- dplyr::case_when(
    results_df$protospacer_seq %in% c("No guides found") ~ "#FBE9EE",
    results_df$mutation_type %in% c("not_editing_intron", "non_editing_exon") ~ "#F7F7F7",
    results_df$mutation_type == "nonsense" | (!is.na(results_df$warnings) & results_df$warnings != "") ~ "#FFF6E8",
    !is.na(results_df$error) & results_df$error != "" ~ "#F6DEE6",
    TRUE ~ "#E9F7F1"
  )
  
  #Gene symbol pills
  if (organism == "human") {
    results_df$gene_symbol <- sprintf(
      '<a href="https://www.genecards.org/cgi-bin/carddisp.pl?gene=%s" 
        target="_blank" 
        style="background-color:#0A1F4D;
               padding:2px 6px;
               border-radius:8px;
               color:#F47B20;
               font-weight:600;
               font-size:16px;
               text-decoration:none;
               display:inline-block;">
        %s</a>',
      results_df$gene_symbol, results_df$gene_symbol
    )
  } else {
    # Map Ensembl IDs to MGI IDs
    mgi_ids <- mapEnsembl2MGI(results_df$ensembl_id)
    
    # Create the MGI link only if a valid ID was found
    results_df$gene_symbol <- vapply(
      seq_along(results_df$gene_symbol),
      function(i) {
        gene <- results_df$gene_symbol[i]
        mgi_id <- mgi_ids[i]
        
        if (!is.na(mgi_id) && mgi_id != "") {
          sprintf(
            '<a href="https://www.informatics.jax.org/marker/%s" 
              target="_blank" 
              style="background-color:#E4EFFD;
                     padding:2px 6px;
                     border-radius:8px;
                     color:#0A1F4D;
                     font-weight:600;
                     font-size:16px;
                     text-decoration:none;
                     display:inline-block;">
              %s</a>',
            mgi_id, gene
          )
        } else {
          gene # leave plain if no valid MGI mapping
        }
      },
      character(1)
    )
  }
  
  
  #UNIPROT ID pills
  results_df$uniprot_id <- vapply(
    results_df$uniprot_id,
    function(uid) {
      if (!is.na(uid) && uid != "") {
        sprintf(
          '<a href="https://www.uniprot.org/uniprotkb/%s"
            target="_blank"
            style="background-color:#0A1F4D;
                   padding:2px 6px;
                   border-radius:8px;
                   color:white;
                   font-weight:600;
                   font-size:16px;
                   text-decoration:none;
                   display:inline-block;">
            %s</a>',
          uid, uid
        )
      } else {
        ""
      }
    },
    character(1)
  )
  
  
  #Ensembl ID pills
  results_df$ensembl_id <- vapply(
    results_df$ensembl_id,
    function(eid) {
      if (!is.na(eid) && eid != "") {
        sprintf(
          '<a href="https://www.ensembl.org/id/%s"
            target="_blank"
            style="background-color:white;
                   padding:2px 6px;
                   border-radius:8px;
                   color:#0A1F4D;
                   font-weight:600;
                   font-size:16px;
                   text-decoration:none;
                   display:inline-block;
                   border:1px solid #0A1F4D;">
            %s</a>',
          eid, eid
        )
      } else {
        ""
      }
    },
    character(1)
  )
  
  #Bold edits
  results_df$edits <- vapply(
    results_df$edits,
    function(ed) {
      if (!is.na(ed)){
        return(paste0("<b>", ed, "<b>"))
      } else {
        return("")
      }
    },
    character(1)
  )
  
  #Style warnings
  results_df$warnings <- vapply(
    results_df$warnings,
    function(w) {
      if (!is.na(w) && w != "") {
        warnings_split <- strsplit(w, "\\.")[[1]]
        warnings_split <- trimws(warnings_split)
        warnings_split <- warnings_split[warnings_split != ""]
        paste0("<b>", paste(warnings_split, collapse = ". "), ".</b>")
      } else {
        ""
      }
    },
    character(1)
  )
  
  
  #Style errors
  results_df$error <- vapply(
    results_df$error,
    function(e) {
      if (!is.na(e) && e != "") {
        paste0("<b>", e, "</b>")
      } else {
        ""
      }
    },
    character(1)
  )
  
  
  #Italicize mutation_type
  results_df$mutation_type <- vapply(
    results_df$mutation_type,
    function(x) {
      if (!is.na(x) && x != "") {
        sprintf("<i>%s</i>", x)
      } else {
        ""
      }
    },
    character(1)
  )
  
  
  # Bold sequence + copy button
  results_df$protospacer_seq <- vapply(
    results_df$protospacer_seq,
    function(seq) {
      if (is.na(seq) || seq == "" || grepl("No guides found|Error", seq, ignore.case = TRUE)) {
        return(sprintf("<b>%s</b>", seq))
      }
      
      sprintf(
        "<div style='display:flex; flex-direction:column; align-items:center;'>
     <b>%s</b>
     <a href='#'
        class='copy-seq'
        data-seq='%s'
        title='Copy sequence'
        style='
          margin-top:4px;
          color:#0A1F4D;
          text-decoration:none;
          cursor:pointer;
        '>
        <i class='fa-solid fa-clipboard'></i>
     </a>
   </div>",
        seq, seq
      )
    },
    character(1)
  )
  
  # Highlight |...| regions bold in sequences
  results_df$wildtype_sequence <- vapply(
    results_df$wildtype_sequence,
    function(seq) {
      if (!is.na(seq) && seq != "") {
        matches <- gregexpr("\\|[^|]*\\|", seq, perl = TRUE)
        regmatches(seq, matches) <- lapply(
          regmatches(seq, matches),
          function(x) paste0("<b>", x, "</b>")
        )
        seq
      } else {
        ""
      }
    },
    character(1)
  )
  
  results_df$mutant_sequence <- vapply(
    results_df$mutant_sequence,
    function(seq) {
      if (!is.na(seq) && seq != "") {
        matches <- gregexpr("\\|[^|]*\\|", seq, perl = TRUE)
        regmatches(seq, matches) <- lapply(
          regmatches(seq, matches),
          function(x) paste0("<b>", x, "</b>")
        )
        seq
      } else {
        ""
      }
    },
    character(1)
  )
  
  # Save final object
  saveRDS(results_df,
          file = file.path(output_folder, paste0(job_name, "_interactive_results.rds")),
          compress = "gzip")
}
