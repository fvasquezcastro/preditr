loadOrganismDataShiny <- function(chr, organism){
  
  if (organism == "mouse") {
    library(BSgenome.Mmusculus.UCSC.mm10)
    genome = BSgenome.Mmusculus.UCSC.mm10
    message("Loaded BSgenome.Mmusculus.UCSC.mm10")
    
    txdb_path = file.path("bin", organism, "txdb", paste0(chr, ".rds"))
    
    return(list(
      txdb = readRDS(txdb_path),
      genome = genome
    ))
    
  }
  
  if (organism == "human"){
    library(BSgenome.Hsapiens.UCSC.hg38)
    genome <- BSgenome.Hsapiens.UCSC.hg38
    
    message("Loaded BSgenome.Hsapiens.UCSC.hg38")
    
    txdb_path = file.path("bin", organism, "txdb", paste0(chr, ".rds"))
    
    return(list(
      txdb = readRDS(txdb_path),
      genome = genome
    ))
  }
  
  
}