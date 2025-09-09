#!/usr/bin/env Rscript

library(Rbowtie)
library(argparser)

args <- arg_parser("Index a genome from the .fa.gz file using Rbowtie")

args <- add_argument(args, 
                     "--fasta_path",
                     help = "Path to the .fa.gz file for the genome of interest",
                     type = "character")

args <- add_argument(args, 
                     "--output_path",
                     help = "Path to the output directory",
                     type = "character")

args <- add_argument(args, 
                     "--prefix",
                     help = "Name for the indexed genome",
                     type = "character")

parsed_args <- parse_args(args)

if (is.null(parsed_args$fasta_path) | is.null(parsed_args$output_path) | is.null(parsed_args$prefix)){
  
  stop("All arguments are required")
}

fasta_path <- parsed_args$fasta_path
output_path <- parsed_args$output_path
prefix <- parsed_args$prefix
  
index_genome <- function(fasta_path, output_path, prefix){
  
  bowtie_build(fasta_path,
               outdir=output_path,
               force=TRUE,
               prefix=prefix)
}

index_genome(fasta_path, output_path, prefix)