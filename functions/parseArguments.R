parseArguments <- function(){
  
  
  args <- argparser::arg_parser("Design sgRNAs to target specific amino acids with base editors using PrEditR")
  
  args <- argparser::add_argument(args, "--input", help = "Path to the input file",
                       type = "character")
  
  args <- argparser::add_argument(args, "--job_name", help = "Job name (no whitespaces)",
                       type = "character",
                       default = "PrEditR_job")
  
  args <- argparser::add_argument(args, "--editors", help = "Path to the file that defines the editors",
                       type = "character")
  
  args <- argparser::add_argument(args, "--output", help = "Path to the output directory",
                       type = "character")
  
  args <- argparser::add_argument(args, "--shiny", help = "Set to TRUE if the image is running through Docker Desktop as a Shiny App",
                       type = "character",
                       default = "FALSE")
  
  args <- argparser::add_argument(args, "--organism", help = "Accepted values: human, mouse",
                       type = "character")
  
  args <- argparser::add_argument(args, "--off_targets", help = "Indicates if PrEditR should search for potential off-targets",
                       type = "character",
                       default = "FALSE")
  
  args <- argparser::add_argument(args, "--n_mismatches", help = "Maximum number of mismatches tolerated
                     for searching for potential off-targets. Maximum is 10.",
                       type = "integer", default=3)
  
  args <- argparser::add_argument(args, "--n_max_alignments", 
                       help = "Guides that align exactly to more than this number of loci will be discarded.",
                       type = "integer", default=3)
  
  args <- argparser::add_argument(args, "--flanking5",
                       help = "Flanking sequence at 5' that will be used to construct the guides library.
                     It will be assessed if the guides concatenated to this sequence at 5'
                     create a site that is recognized by EcoRI, KpnI, 
                     BsmBI, BsaI, BbsI, PacI.", type = "character", default = "")
  
  args <- argparser::add_argument(args, "--flanking3",
                       help = "Flanking sequence at 3' that will be used to construct the guides library.
                     It will be assessed if the guides concatenated to this sequence at 3'
                     create a site that is recognized by EcoRI, KpnI, 
                     BsmBI, BsaI, BbsI, PacI.", type = "character", default = "")
  
  args <- argparser::add_argument(args, "--indexed_genome",
                       help = "Path to the folder that contains .ebwt files for the external genome provided",
                       type = "character")
  
  args <- argparser::add_argument(args, "--threads", help = "Number of workers for multiprocessing. If you are getting an out-of-memory (OOM) error, 
                       consider reducing the number of workers of increasing the RAM available for the job.",
                       type = "integer", default = 4)
  
  args <- argparser::add_argument(args, "--tmp", help = "Path to a temporary folder. The contents of the folder will be deleted",
                       type = "character")
  
  args <- argparser::add_argument(args, "--non_editing_controls", help = "Indicates if PrEditR will search for non-editing guides.",
                       type = "character", default = "FALSE")
  
  
  parsed_args <- argparser::parse_args(args)
  
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
    non_editing_controls = parsed_args$non_editing_controls,
    tmp = parsed_args$tmp
  ))
}
