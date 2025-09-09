
findPotentialACL <- function(genome, ensembl_id, target_position, txdb) {
  
  cds_coordinates <- queryTxObject(txObject=txdb, #Find cds_coordinates for a specific transcript
                               featureType="cds",
                               queryColumn="tx_id",
                               queryValue=ensembl_id)
  

  if (length(cds_coordinates) == 0){
    logError("ENSEMBL ID provided does not exist in the database. Only provide IDs without version numbers (<ID>.<version_number>)")
    return(NULL)  
  }
  
  gene_symbol <- cds_coordinates$gene_symbol[1]
    
    
  if (length(unique(cds_coordinates@strand)) > 1){ #Just in case queryTxObject() retrieves both cds_coordinates for the positive and negative strands, which is highly unlikely but just in case
    
    positive_rows <- which(cds_coordinates@strand == "+")
    cds_coordinates <- cds_coordinates[positive_rows] #Only keep positive
    
  }
  
  
  cds <- getSeq(genome, cds_coordinates) #coding sequences
  
  
  codon_relative_end <- (target_position)*3 #Must be included in the range
  codon_relative_start <- codon_relative_end - 2 #Must be included in the range
  

  current_region <- which(cumsum(cds@ranges@width) - codon_relative_start >= 0)[1]

  
  if (is.na(current_region)){
    
    #There could be a chance that the position targeted exists in the transcript but the transcript is truncated at 3'
    tryCatch({
      
      txtable <- getTxInfoDataFrame(tx_id=ensembl_id, #Get txdb table from txdb object
                                    txObject=txdb,
                                    bsgenome=genome)
      
    }, error = function(e){
      
      if (conditionMessage(e) == "The specified tx_id has a CDS with incomplete length."){
        
        logError(paste0("Position ", target_position, " is greater than the last position in transcript ", ensembl_id,  " , whose coding sequence is truncated at 3' in the database"))
        
        return(NULL)
      }
    })
    
    last_aa <- last(cumsum(cds@ranges@width))/3
    
    logError(paste0("Position ", target_position, " is greater than the last position in transcript ", ensembl_id, " which is ", last_aa))
    
    return(NULL)
  }
  
  if (current_region - 1 >= 1) {
    
    previous_region <- current_region - 1
    
  } else {
    
    previous_region <- NULL
  }
  
  
  if (unique(cds_coordinates@strand) == "+"){
    
    if (is.null(previous_region)){
      
      codon_absolute_start <- cds_coordinates[1]@ranges@start + codon_relative_start - 1
      
    } else {
      
      codon_absolute_start <- cds_coordinates[current_region]@ranges@start + (codon_relative_start - sum(cds_coordinates[1:previous_region]@ranges@width)) - 1
      
    }
    
    
    presumed_absolute_codon_end <- codon_absolute_start + 2 #Assuming there is no splice site interrupting the codon
    
    difference <- end(cds_coordinates[current_region]@ranges) - presumed_absolute_codon_end
    if (difference < 0){ #This will only happen when the codon is formed by bases in two different exons
      
      if (abs(difference) == 1){ #Only one base is in the next exon
        
        codon_absolute_middle <- codon_absolute_start + 1
        codon_absolute_end <- cds_coordinates[current_region+1]@ranges@start
        
      }
      
      if (abs(difference) == 2){ #Two bases are in the next exon
        
        codon_absolute_middle <- cds_coordinates[current_region+1]@ranges@start
        codon_absolute_end <- codon_absolute_middle + 1 
        
        
      }

      
    } 
      
      codon_absolute_middle <- codon_absolute_start + 1
      codon_absolute_end <- codon_absolute_start + 2
      
    
    
    strand <- "+"
    
    return(list(
      potentialACL=c(codon_absolute_start, codon_absolute_middle, codon_absolute_end),
      cds_coordinates = cds_coordinates,
      strand = strand,
      gene_symbol = gene_symbol
    ))
    
  }
  
  if (unique(cds_coordinates@strand) == "-"){
    
    if (is.null(previous_region)){
      
      codon_absolute_start <- end(cds_coordinates[current_region]@ranges) - codon_relative_start + 1
      
    } else {
      
      codon_absolute_start <- end(cds_coordinates[current_region]@ranges) - (codon_relative_start - sum(cds_coordinates[1:previous_region]@ranges@width)) + 1
      
      
    }
    #Inversed for the negative strand. The cds_coordinates increase from 3'-5' (?)
    
    presumed_absolute_codon_end <- codon_absolute_start -2 
    
    difference <- cds_coordinates[current_region]@ranges@start - presumed_absolute_codon_end
    
    if (difference > 0){
      
      if (difference == 1) {
        
        codon_absolute_middle <- codon_absolute_start - 1
        codon_absolute_end <- end(cds_coordinates[current_region+1]@ranges)
        
      }
      
      if (difference == 2){
        
        codon_absolute_middle <- end(cds_coordinates[current_region+1]@ranges)
        codon_absolute_end <- codon_absolute_middle - 1
        
      }
      
      
      
    } else {
      
      codon_absolute_middle <- codon_absolute_start - 1
      codon_absolute_end <- codon_absolute_start - 2
      
      
    }

    
    strand <- "-"
    
    
    return(list(
      potentialACL=c(codon_absolute_end, codon_absolute_middle, codon_absolute_start), #It is really start, middle, end because the cds_coordinates in the neg stand are opposite. In summary, start < middle < end, and the numbers increase in the 3' direction 
      cds_coordinates = cds_coordinates,
      strand = strand,
      gene_symbol = gene_symbol
    ))
    
  }
  
  
}