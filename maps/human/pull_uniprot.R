library(httr2)
library(jsonlite)
library(dplyr)
library(magrittr)

ensembl_ids <- as.vector(read.table("ensembl_in_txdb.txt")$V1)

biomart_export <- read.table(
  gzfile("biomart_export_20251120.txt.gz"),
  header = TRUE, sep = "\t"
)

biomart_export <- biomart_export[
  biomart_export$Transcript.stable.ID %in% ensembl_ids, 
]

#In most cases, the UniProt canonical isoform is the 
get_canonical_isoform <- function(uniprot_id) {
  if (is.na(uniprot_id) || uniprot_id == "") return(NA)
  
  clean_uniprot_id <- sub("-[0-9]+$", "", uniprot_id)
  url <- paste0("https://rest.uniprot.org/uniprotkb/", clean_uniprot_id, ".json")
  
  resp <- tryCatch({
    request(url) %>%
      req_retry(max_tries = 3) %>% # Better than basic tryCatch for network issues
      req_perform()
  }, error = function(e) {
    message("Request failed for ", clean_uniprot_id)
    return(NULL)
  })
  
  if (is.null(resp)) return(NA)
  
  data <- resp %>% resp_body_json()
  
  # Look for the Alternative Products comment
  alt_products <- Filter(function(x) identical(x$commentType, "ALTERNATIVE PRODUCTS"), data$comments)
  
  if (length(alt_products) > 0) {
    return(alt_products[[1]]$isoforms[[1]]$isoformIds[[1]])
  }
  
  return(NA)
}

uniprot_canonical_map <- biomart_export %>%
  dplyr::select(UniProtKB.Swiss.Prot.ID) %>%
  distinct() %>%
  filter(UniProtKB.Swiss.Prot.ID != "")

canonical_ids <- sapply(uniprot_canonical_map$UniProtKB.Swiss.Prot.ID, get_canonical_isoform)

uniprot_canonical_map$queried_canonical <- canonical_ids
write.csv(uniprot_canonical_map, file = "uniprot_queried_canonical.csv", row.names = FALSE)