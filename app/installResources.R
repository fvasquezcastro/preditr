#!/usr/bin/env Rscript

#install.packages("devtools")
#install.packages("remotes")
#remotes::install_version("BiocManager", version = "1.30.25", repos = "http://cran.us.r-project.org")

#Core Packages
install.packages("argparser", version = "0.7.2")
install.packages("furrr", version = "0.3.1")
install.packages("purrr", version = "1.0.4")  
install.packages("future", version = "1.34.0")  
install.packages("future.apply", version = "1.11.3")  
install.packages("parallel", version = "4.4.1")  
install.packages("dplyr", version = "1.1.4")
install.packages("gtools", version = "3.9.5")  
install.packages("logger", version = "0.4.0")  
install.packages("stringr", version = "1.51")
install.packages("fastmatch", version = "1.1-6")
install.packages("progressr", version = "0.15.1")
install.packages("promises", version = "1.3.3")
install.packages("tryCatchLog", version = "1.3.1")
install.packages("memuse", version = "4.2-3")
install.packages("ParallelLogger", version = "3.4.2")
install.packages("yaml", version = "2.3.10")

BiocManager::install("GenomicFeatures")  
BiocManager::install("Biostrings")
BiocManager::install("Rbowtie")
BiocManager::install("crisprBowtie")
BiocManager::install("crisprBwa")
BiocManager::install("crisprBase")
BiocManager::install("crisprDesign")
BiocManager::install("crisprScore")
BiocManager::install("crisprScoreData")
devtools::install_github("crisprVerse/crisprDesignData")

#Shiny App
install.packages("shiny", version = "1.10.0")
install.packages("bslib", version = "0.9.0")
install.packages("DT", version = "0.33")
install.packages("readr", version = "2.1.5")
install.packages("shinyjs", version = "2.1.0")
install.packages("shinybusy", version = "0.3.3")

#Organism Data
#Human
BiocManager::install("BSgenome.Hsapiens.UCSC.hg38", ask = FALSE, update = FALSE)

#Mouse 
BiocManager::install("BSgenome.Mmusculus.UCSC.mm10")