argsChecker <- function(input, job_name, editors, output, organism, tmp,
                        off_targets, indexed_genome, n_mismatches) {
  
  
  if (is.null(input) || is.null(job_name) || is.null(editors) || is.null(output) || is.null(organism) || is.null(tmp)) {
    
    ParallelLogger::logError("The arguments --input, --job_name, --editors, --output, --organism, --tmp are required. Run ProteinEdit.R --help for more information if on the command line. More help can be found on the GitHub page.")
    return(1)
  }
  
  if (off_targets == "TRUE" & is.null(indexed_genome)) {
    
    ParallelLogger::logError("An indexed genome is required to perform off-target searches.")
    return(1)
  }
  
  #Check the job name
  if (grepl("[^A-Za-z0-9()._]", job_name)) {
    ParallelLogger::logError("Job name contains invalid characters. Only letters, numbers, parentheses, underscores, and dots are allowed.")
    return(1)
  }
  
  #The output directory must exist
  if (!dir.exists(output)){
    ParallelLogger::logError("The output directory does not exist.")
    return(1)
  }
  
  #The temporary directory must exist
  if (!dir.exists(tmp)){
    ParallelLogger::logError("The temporary directory does not exist.")
    return(1)
  }
  
  #Check the n_mismatches value. It cannot exceed 10
  if (as.integer(n_mismatches) > 10){
    ParallelLogger::logError("The n_mismatches parameter cannot be larger than 10.")
    return(1)
  }
  
  #Check that the directory with the .ebwt files exists and contains at least one .ebtw file
  if (off_targets){
    if (!(dir.exists(indexed_genome))){
      ParallelLogger::logError("Indexed_genome directory does not exist.")
      return(1)
    } else {
      
      ebwt_files <- list.files(indexed_genome, pattern = "\\.ebwt$", full.names = TRUE)
      
      if (length(ebwt_files) == 0){
        
        ParallelLogger::logError("The indexed_genome directory does not contain .ebwt files.")
        return(1)
      }
    }
  }
  #Check that the input file exists
  if (!file.exists(input)){
    ParallelLogger::logError(paste0("The input file at: ", input, " does not exist."))
    return(1)
  }
  
  #Check that the input contains all the required columns
  input_required_columns <- c("gene_symbol", "ensembl_id", "uniprot_id", "target_aa", "target_position", "editor", "edit_type")
  input_df <- read.csv(input, colClasses = "character", blank.lines.skip	= TRUE)
  input_df[] <- lapply(input_df, function(x) if (is.character(x)) trimws(x) else x) #Forces cells with spaces to empty strings. Useful for error handling later
  input_df <- input_df[rowSums(input_df != "" & !is.na(input_df)) > 0, ] #Removes rows that are entirely empty (all NA or all "")
  
  input_cols <- colnames(input_df)
  
  if (sum(input_cols %in% input_required_columns) != length(input_required_columns)){
    
    ParallelLogger::logError(paste0("The input file does not contain all the required columns, which are ", paste(input_required_columns, collapse = ","), " .Providing an ENSEMBL ID is not necessary if gene symbol is provided."))
    return(1)
  }
  
  #Check that each row in the input indicates an ensembl_id or uniprot_id
  invalid_rows <- with(
    input_df,
      (is.na(ensembl_id) | ensembl_id == "") &
      (is.na(uniprot_id) | uniprot_id == "")
  )
  
  if (any(invalid_rows)) {
    ParallelLogger::logError("Every row must have a value for ensembl_id or uniprot_id but both fields cannot be left empty.")
    return(1)
  }
  
  #Check that the input file contains a value for all the required columns for every row
  invalid_rows <- with(
    input_df,
    (is.na(target_aa) | target_aa == "") | (is.na(target_position) | target_position == "") |
      (is.na(editor) | editor == "") | (is.na(edit_type) | edit_type == "")
  )
  
  if (any(invalid_rows)) {
    ParallelLogger::logError("Every row must have a value for target_aa, target_position, editor, and edit_type.")
    return(1)
  }
  
  #Check if multiple Ensembl IDs are associated if just a UNIPROT ID is provided. Prompt the user to specify the isoforms
  #uniprot_only_rows <- with(
  #  input_df,
  #  (is.na(ensembl_id) | ensembl_id == "")
  #)
  
  #uniprot_idx <- unique(as.vector(input_df[uniprot_only_rows, ]$uniprot_id))
  
  #duplicated_idx <- readRDS(file = file.path("maps", organism, "duplicated_uniprot.rds"))
  
  #dup_mask <- uniprot_idx %in% duplicated_idx
  
  #dups <- sum(dup_mask)
  
  #if (dups >0){
    
  #  logWarn(paste0("The UNIPROT IDs ", paste(uniprot_idx[dup_mask], collapse = ", "), " are associated to several isoforms. Please indicate the specific one (e.g., O60346-1 instead of O60346)"))
  #  return(1)
  #}
  
  #Check that the editor file exists
  if (!file.exists(editors)){
    ParallelLogger::logError(paste0("The input file at: ", editors, " does not exist."))
    return(1)
  }
  
  #Check that the editors file contains all the required columns
  editor_required_columns <- c("editor_name", "pam", "spacer_length", "edit_type", "edit_window_min", "edit_window_max")
  editor_df <- read.csv(editors, header = TRUE,
                        colClasses = "character", blank.lines.skip	= TRUE)
  
  editor_cols <- colnames(editor_df)
  
  if (sum(editor_cols %in% editor_required_columns) != length(editor_required_columns)){
    
    ParallelLogger::logError(paste0("The editor file does not contain all the required columns, which are ", 
                paste(editor_required_columns, collapse = ","), "."))
    return(1)
    
  }
  
  #Check that there is at least one editor defined
  if (nrow(editor_df) == 0){
    ParallelLogger::logError("At least one editor must be defined in the editors table.")
    return(1)
  }
  
  #Check if there is any editor meant to be used in the input but not defined in the editors table
  required_editors <- unique(input_df$editor)
  defined_editors <- unique(editor_df$editor_name)
  
  missing_editors <- required_editors[!(required_editors %in% defined_editors)]
  if (length(missing_editors) > 0 ){
    ParallelLogger::logError(paste0("The following editor(s) are not defined in the editors table: ", missing_editors, "."))
    return(1)
  }
  
  #Check that editor names are unique
  if (length(unique(editor_df$editor_name)) != nrow(editor_df)){
    ParallelLogger::logError("All editor names must be unique.")
    return(1)
  }
  
  # Check that no required editor field is left empty
  if (any(sapply(editor_df[editor_required_columns], function(col) any(is.na(col) | col == "")))) {
    ParallelLogger::logError("All editors must have values in the columns editor_name, pam, spacer_length, edit_type, edit_window_min, edit_window_max.")
    return(1)
  }
  
  #If off-target searches are turned on, all the editors used in the input file must have
  #the same spacer length defined
  if (off_targets){
    
    required_editors <- unique(editor_df$editor)
    spacer_lens <- unique(editor_df[editor_df$editor_name %in% required_editors, ]$spacer_length)
    
    if (length(spacer_lens) > 1){
      ParallelLogger::logError("When off-target searches are enabled, all editors in the input file must generate spacers of the same length.")
      return(1)
      
    }
  }
  
  #Check that the input file does not contain columns that are reserved for the output
  output_columns <- c("query_num", "gene_strand", "protospacer_seq", "percent_gc", "pam_seq", "protospacer_strand",
                      "chromosome", "pam_coordinates", "mutation_type", "wildtype_sequence",
                      "mutant_sequence", "edits","warnings", "error", "EcoRI", "KpnI", "BsmbI", "BsaI", "BbsI", "PacI",
                      "MluI", "alignments_n0", "alignments_n1", "alignments_n2", "alignments_n3",
                      "alignments_n4", "alignments_n5", "alignments_n6", "alignments_n7", "alignments_n8",
                      "alignments_n9", "alignments_n10")
  
  invalid_cols <- input_cols %in% output_columns
  
  if (any(invalid_cols)){
    
    ParallelLogger::logError(paste0("The following column names are reserved for the output and cannot be used in the input: ",
                paste(output_columns, collapse = ","), "."))
    return(1)
    
  }
  
  
  return(0)
}