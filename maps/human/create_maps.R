library(dplyr)
library(data.table)
library(httr2)
library(jsonlite)

### ============================
### Load inputs
### ============================

ensembl_ids <- as.vector(read.table("maps/human/ensembl_in_txdb.txt")$V1)

biomart_export <- read.table(
  gzfile("maps/human/biomart_export_20251120.txt.gz"),
  header = TRUE, sep = "\t"
)

biomart_export <- biomart_export[
  biomart_export$Transcript.stable.ID %in% ensembl_ids, 
]


selected_uniprot_ids <- ifelse(
  nzchar(biomart_export$UniProtKB.isoform.ID),
  biomart_export$UniProtKB.isoform.ID,
  biomart_export$UniProtKB.Swiss.Prot.ID
)

biomart_export$selected_uniprot <- selected_uniprot_ids


### ============================================================
### 1. Build ENSEMBL → UNIPROT map (isoform-aware, 1-to-1)
### ============================================================

ensembl_to_uniprot <- new.env(hash = TRUE, parent = emptyenv())

for (i in seq_len(nrow(biomart_export))) {
  key <- biomart_export$Transcript.stable.ID[i]
  
  value <- biomart_export$selected_uniprot[i]
  
  ensembl_to_uniprot[[key]] <- value
}

# Save RDS
saveRDS(ensembl_to_uniprot, "maps/human/ensembl_to_uniprot.rds", compress = "xz")

# Save a flat table
biomart_export_ensembl_map <- biomart_export %>%
  mutate(UNIPROT_ID = ifelse(
    !is.na(UniProtKB.isoform.ID) & UniProtKB.isoform.ID != "",
    UniProtKB.isoform.ID,
    UniProtKB.Swiss.Prot.ID
  ))

fwrite(
  biomart_export_ensembl_map,
  "maps/human/ensembl_to_uniprot.txt.gz",
  sep = "\t", quote = FALSE, compress = "gzip"
)



### ============================================================
### 2. Build UNIPROT → ENSEMBL map
### ============================================================

# Build the environment
uniprot_to_ensembl <- new.env(hash = TRUE, parent = emptyenv())

for (i in seq_len(nrow(biomart_export))) {
  key <- biomart_export$selected_uniprot[i] 
  if (!nzchar(key)) {next} #Some have no UNIPROT ID associated; skip 
  value <- biomart_export$Transcript.stable.ID[i]
  uniprot_to_ensembl[[key]] <- value
}

#Add Ensembl canonical. They might not necessarily match with UniProt canonical, but it does
#in many cases so it defaults to it if no isoform is specified when using UniProt ids.
biomart_export_canonical <- biomart_export[which(biomart_export$Ensembl.Canonical == 1), ]

for (i in seq_len(nrow(biomart_export_canonical))) {
  key <- biomart_export_canonical$UniProtKB.Swiss.Prot.ID[i] 
  if (!nzchar(key)) {next}
  value <- biomart_export_canonical$Transcript.stable.ID[i]
  uniprot_to_ensembl[[key]] <- value
}


# Save the RDS
saveRDS(uniprot_to_ensembl, "maps/human/uniprot_to_ensembl.rds", compress = "xz")

### ============================================================
### 3. Save base UniProt IDs that have isoforms to flag them
### ============================================================
has_isoforms <- new.env(hash = TRUE, parent = emptyenv())

biomart_isoforms <- biomart_export[nzchar(biomart_export$UniProtKB.isoform.ID), ]
isoforms_ids <- unique(biomart_isoforms$UniProtKB.Swiss.Prot.ID)

for (i in isoforms_ids){
  
  has_isoforms[[i]] <- TRUE
  
}
saveRDS(has_isoforms, "maps/human/has_isoforms.rds", compress = "xz")

### ============================================================
### 4. Save list of duplicated canonical UniProt IDs
### ============================================================

all_uniprot <- as.vector(biomart_export$UniProtKB.Swiss.Prot.ID)
duplicated_uniprot <- unique(all_uniprot[duplicated(all_uniprot)])

saveRDS(duplicated_uniprot, file = "maps/human/duplicated_uniprot.rds")

