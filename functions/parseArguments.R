parseArguments <- function(){
  
  
  args <- arg_parser("Design sgRNAs to target specific amino acids with base editors using PrEditR")
  
  args <- add_argument(args, "--input", help = "Path to the input file",
                       type = "character")
  
  args <- add_argument(args, "--job_name", help = "Job name (no whitespaces)",
                       type = "character",
                       default = "PrEditR_job")
  
  args <- add_argument(args, "--editors", help = "Path to the file that defines the editors",
                       type = "character")
  
  args <- add_argument(args, "--output", help = "Path to the output directory",
                       type = "character")
  
  args <- add_argument(args, "--shiny", help = "Set to TRUE if the image is running through Docker Desktop as a Shiny App",
                       type = "character",
                       default = "FALSE")
  
  args <- add_argument(args, "--organism", help = "Accepted values: human, mouse",
                       type = "character")
  
  args <- add_argument(args, "--off_targets", help = "Indicates if PrEditR should search for potential off-targets",
                       type = "character",
                       default = "FALSE")
  
  args <- add_argument(args, "--n_mismatches", help = "Maximum number of mismatches tolerated
                     for searching for potential off-targets. Maximum is 10.",
                       type = "integer", default=3)
  
  args <- add_argument(args, "--n_max_alignments", 
                       help = "Guides that align exactly to more than this number of loci will be discarded.",
                       type = "integer", default=3)
  
  args <- add_argument(args, "--flanking5",
                       help = "Flanking sequence at 5' that will be used to construct the guides library.
                     It will be assessed if the guides concatenated to this sequence at 5'
                     create a site that is recognized by EcoRI, KpnI, 
                     BsmBI, BsaI, BbsI, PacI.", type = "character", default = "")
  
  args <- add_argument(args, "--flanking3",
                       help = "Flanking sequence at 3' that will be used to construct the guides library.
                     It will be assessed if the guides concatenated to this sequence at 3'
                     create a site that is recognized by EcoRI, KpnI, 
                     BsmBI, BsaI, BbsI, PacI.", type = "character", default = "")
  
  args <- add_argument(args, "--indexed_genome",
                       help = "Path to the folder that contains .ebwt files for the external genome provided",
                       type = "character")
  
  args <- add_argument(args, "--threads", help = "Number of workers for multiprocessing. If you are getting an out-of-memory (OOM) error, 
                       consider reducing the number of workers of increasing the RAM available for the job.",
                       type = "integer", default = 4)
  
  args <- add_argument(args, "--tmp", help = "Path to a temporary folder. The contents of the folder will be deleted",
                       type = "character")
  
  args <- add_argument(args, "--non_targeting_controls", help = "Indicates if PrEditR will search for non-targeting guides.",
                       type = "character", default = "FALSE")
  
  parsed_args <- parse_args(args)
  
  
  if (is.null(parsed_args$input) || is.null(parsed_args$job_name) || is.null(parsed_args$editors) || is.null(parsed_args$output) || is.null(parsed_args$organism) || is.null(parsed_args$tmp)) {
    
    stop("The arguments --input, --job_name, --editors, --output, --organism, --tmp are required. 
         Run ProteinEdit.R --help for more information.")
  }
  
  if (parsed_args$off_targets == "TRUE" & is.null(parsed_args$indexed_genome)) {
    
    stop("An indexed genome is required to perform off-target searches.")
  }
  
  #Check the job name
  if (grepl("[^A-Za-z0-9()._]", parsed_args$job_name)) {
    stop("Job name contains invalid characters. Only letters, numbers, parentheses, underscores, and dots are allowed.")
  }
  
  #The output directory must exist
  if (!dir.exists(parsed_args$output)){
    stop("The output directory does not exist.")
  }
  
  #Check the n_mismatches value. It cannot exceed 10
  if (as.integer(parsed_args$n_mismatches) > 10){
    stop("The n_mismatches parameter cannot be larger than 10.")
  }
  
  #Check that the directory with the .ebwt files exists and contains at least one .ebtw file
  if (!(dir.exists(parsed_args$indexed_genome))){
    stop("Indexed_genome directory does not exist.")
  } else {
    
    ebwt_files <- list.files(parsed_args$indexed_genome, pattern = "\\.ebwt$", full.names = TRUE)
    
    if (length(ebwt_files) == 0){
      
      stop("The indexed_genome directory does not contain .ebwt files.")
      
    }
  }
  
  #Check that the input file exists
  if (!file.exists(parsed_args$input)){
    stop(paste0("The input file at: ", parsed_args$input, " does not exist."))
  }
  
  #Check that the input contains all the required columns
  input_required_columns <- c("gene_symbol", "ensembl_id", "target_aa", "target_position", "editor", "edit_type")
  input_df <- read.csv(parsed_args$input, colClasses = "character", blank.lines.skip	= TRUE)
  
  input_cols <- colnames(input_df)
  
  if (sum(input_cols %in% input_required_columns) != length(input_required_columns)){
    
    stop(paste0("The input file does not contain all the required columns, which are ", 
                           paste(input_required_columns, collapse = ","), " .Providing an ENSEMBL ID is not necessary if gene symbol is provided."))
  }
  
  #Check that each row in the input indicates a gene_symbol or ensembl_id but both cannot be left empty
  invalid_rows <- with(input_df, (is.na(gene_symbol) | gene_symbol == "") &
                         (is.na(ensembl_id) | ensembl_id == ""))
  
  if (any(invalid_rows)) {
    stop("Each row must have a value in either gene_symbol or ensembl_id.")
  }
  
  #Check that the editor file exists
  if (!file.exists(parsed_args$editors)){
    stop(paste0("The input file at: ", parsed_args$editors, " does not exist."))
  }
  
  #Check that the editors file contains all the required columns
  editor_required_columns <- c("editor_name", "pam", "spacer_length", "edit_type", "edit_window_min", "edit_window_max")
  editor_df <- read.csv(parsed_args$editors, header = TRUE,
           colClasses = "character", blank.lines.skip	= TRUE)
  
  editor_cols <- colnames(editor_df)
  
  if (sum(editor_cols %in% editor_required_columns) != length(editor_required_columns)){
    
    stop(paste0("The editor file does not contain all the required columns, which are ", 
                           paste(editor_required_columns, collapse = ","), "."))
    
  }
  
  #Check that there is at least one editor defined
  if (nrow(editor_df) == 0){
    stop("At least one editor must be defined in the editors table.")
  }
  
  #Check if there is any editor meant to be used in the input but not defined in the editors table
  required_editors <- unique(input_df$editor)
  defined_editors <- unique(editor_df$editor_name)
  
  missing_editors <- required_editors[!(required_editors %in% defined_editors)]
  if (length(missing_editors) > 0 ){
    stop(paste0("The following editor(s) are not defined in the editors table: ", missing_editors, "."))
  }
  
  #Check that editor names are unique
  if (length(unique(editor_df$editor_name)) != nrow(editor_df)){
    stop("All editor names must be unique.")
  }
  
  #Check that no editor field is left empty
  if (any(sapply(editor_df, function(col) any(is.na(col) | col == "")))) {
    stop("All values are required in the editors table for every editor.")
  }
  
  #If off-target searches are turned on, all the editors used in the input file must have
  #the same spacer length defined
  if (parsed_args$off_targets){
    
    required_editors <- unique(editor_df$editor)
    spacer_lens <- unique(editor_df[editor_df$editor_name %in% required_editors, ]$spacer_length)
  
    if (length(spacer_lens) > 1){
      stop("When off-target searches are enabled, 
           all editors in the input file must generate spacers of the same length.")
      
    }
  }
  
  #Check that the input file does not contain columns that are reserved for the output
  output_columns <- c("row_num", "gene_strand", "protospacer_seq", "percent_gc", "pam_seq", "protospacer_strand",
                      "chromosome", "pam_coordinates", "mutation_type", "wildtype_sequence",
                      "mutant_sequence", "edits","EcoRI", "KpnI", "BsmbI", "BsaI", "BbsI", "PacI",
                      "MluI", "alignments_n0", "alignments_n1", "alignments_n2", "alignments_n3",
                      "alignments_n4", "alignments_n5", "alignments_n6", "alignments_n7", "alignments_n8",
                      "alignments_n9", "alignments_n10")
  
  invalid_cols <- input_cols %in% output_columns
  
  if (any(invalid_cols)){
    
    stop(paste0("The following column names are reserved for the output and cannot be used in the input: ",
                           paste(output_columns, collapse = ","), "."))
    
  }
  
  
  
  
  return(list(
    input = parsed_args$input,
    job_name = parsed_args$job_name,
    editors = parsed_args$editors,
    output_path = parsed_args$output,
    organism = parsed_args$organism,
    indexed_genome = parsed_args$indexed_genome,
    n_mismatches = parsed_args$n_mismatches,
    n_max_alignments = parsed_args$n_max_alignments,
    flanking5 = parsed_args$flanking5,
    flanking3 = parsed_args$flanking3,
    threads = parsed_args$threads,
    shiny = parsed_args$shiny,
    off_targets = parsed_args$off_targets,
    non_targeting_controls = parsed_args$non_targeting_controls,
    tmp_folder = parsed_args$tmp
  ))
}
