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
BiocManager::install("pwalign", ask = FALSE, update = FALSE)  # BLOSUM62 moved here from Biostrings in Bioc 3.19
BiocManager::install("crisprBase", ask = FALSE, update = FALSE)
BiocManager::install("crisprDesign", ask = FALSE, update = FALSE)
BiocManager::install("AnnotationHub", ask = FALSE, update = FALSE)

# Genome (BSgenome) and annotation (crisprDesignData) data are no longer baked in.
# They ship per-organism in the preditr-ref images and are loaded at runtime from
# PREDITR_REFERENCES_PATH by functions/loadReference.R. The reference images are
# built in the separate preditr_ref repo (see its references/docs/).

install.packages("shiny")
install.packages("bslib")
install.packages("DT")
install.packages("readr")
install.packages("shinyjs")
install.packages("shinybusy")
install.packages("ggplot2")