loadOrganismData <- function(x) {
  
  if (x == "mouse") {
    data("txdb_mouse", package="crisprDesignData") #Load the txdb table to the global environment
    library(BSgenome.Mmusculus.UCSC.mm10)
    genome = BSgenome.Mmusculus.UCSC.mm10
    
    message("Loaded BSgenome.Mmusculus.UCSC.mm10")
    
    return(list(
      txdb = txdb_mouse,
      genome = genome
    ))
    
  }
  
  if (x == "human"){
    data("txdb_human", package="crisprDesignData")
    library(BSgenome.Hsapiens.UCSC.hg38)
    genome <- BSgenome.Hsapiens.UCSC.hg38
    
    message("Loaded BSgenome.Hsapiens.UCSC.hg38")
    return(list(
      txdb = txdb_human,
      genome = genome
      ))
  }
  
}