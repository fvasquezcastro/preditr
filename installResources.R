#!/usr/bin/env Rscript

options(repos = c(CRAN = "https://cloud.r-project.org"))

if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}

BiocManager::install(version = "3.19", ask = FALSE, update = FALSE)

install.packages("argparser")
install.packages("furrr")
install.packages("purrr")
install.packages("future")
install.packages("gtools")
install.packages("stringr")
install.packages("fastmatch")
install.packages("progressr")
install.packages("promises")
install.packages("tryCatchLog")
install.packages("memuse")
install.packages("ParallelLogger")
install.packages("yaml")
install.packages("svglite")
install.packages("forcats")
install.packages("dplyr")

BiocManager::install("GenomicFeatures", ask = FALSE, update = FALSE)
BiocManager::install("Biostrings", ask = FALSE, update = FALSE)
BiocManager::install("crisprBase", ask = FALSE, update = FALSE)
BiocManager::install("crisprDesign", ask = FALSE, update = FALSE)
BiocManager::install("AnnotationHub", ask = FALSE, update = FALSE)

install.packages("devtools")
devtools::install_github("crisprVerse/crisprDesignData", upgrade = "never")

install.packages("shiny")
install.packages("bslib")
install.packages("DT")
install.packages("readr")
install.packages("shinyjs")
install.packages("shinybusy")
install.packages("ggplot2")

BiocManager::install("BSgenome.Hsapiens.UCSC.hg38", ask = FALSE, update = FALSE)
BiocManager::install("BSgenome.Mmusculus.UCSC.mm10", ask = FALSE, update = FALSE)