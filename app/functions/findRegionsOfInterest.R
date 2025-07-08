findRegionsOfInterest <- function(all_coordinates, codon_absolute_locations, editor){
  
  all_regions <- names(all_coordinates)
  intron_regions <- sort(as.integer(str_extract(str_extract(all_regions, "region_\\d+_intron"), "\\d+")))
  exon_regions <- sort(as.integer(str_extract(str_extract(all_regions, "region_\\d+_exon"), "\\d+")))
  
  spacer_length <- get(editor)@spacer_length
  
  codon_start <- codon_absolute_locations[1]
  codon_middle <- codon_absolute_locations[2]
  codon_end <- codon_absolute_locations[3]
  
  codon_start_region <- which((all_coordinates@ranges@start <= codon_start & codon_start <= end(all_coordinates@ranges)))
  codon_end_region <- which((all_coordinates@ranges@start <= codon_end & codon_end <= end(all_coordinates@ranges))) 

  exons <- c()
  introns <- c()
  
  if (codon_start_region == codon_end_region){
    
    current_exon <- as.integer(str_extract(names(all_coordinates[codon_start_region, ]), "\\d+"))
    exons <- c(exons, current_exon)
    
    #Find which intron is closest to include
    
    if (current_exon == 1){ #Then just consider the following intron, which is the same number but for intron
      
      if (current_exon %in% intron_regions){
        
        next_intron_start <- all_coordinates[names(all_coordinates) == paste0("region_", current_exon, "_intron"), ]@ranges@start
          
        if (next_intron_start - codon_middle <= 2*spacer_length){ #If it is sufficiently close, sufficiently defined as 2x the spacer length
          
          introns <- c(introns, current_exon)
        }
      }
      
      
    } else { #Still the entire codon on one exon but not the first one
      
      #print("here")
      next_intron_start <- as.integer(all_coordinates[names(all_coordinates) == paste0("region_", current_exon, "_intron"), ]@ranges@start)
      previous_intron_end <- as.integer(end(all_coordinates[names(all_coordinates) == paste0("region_", current_exon-1, "_intron"), ]@ranges))
      
      #print(codon_middle)
      #print(next_intron_start)
      #print(previous_intron_end)
      #print(2*spacer_length)
      
      if (current_exon %in% intron_regions){
        
        if (next_intron_start - codon_middle <= 2*spacer_length){
          
          introns <- c(introns, current_exon)
        }
        
      }

      if (current_exon -1 %in% intron_regions){
        
        if (codon_middle - previous_intron_end <= 2*spacer_length){
          
          introns <- c(introns, current_exon-1)
        }
        
      }

      
    }
    
    
  } else {
    
    exon1 <-  as.integer(str_extract(names(all_coordinates[codon_start_region, ]), "\\d+"))
    exon2 <- as.integer(str_extract(names(all_coordinates[codon_end_region, ]), "\\d+"))
    
    exons <- c(exons, exon1, exon2)
    introns <- c(introns, exon1) #Because if region n+1 is an intron, it keeps the same number as the previous exon
    
  }
  
  
  introns <- paste0("region_", as.character(introns), "_intron")
  exons <- paste0("region_", as.character(exons), "_exon")
  
  
  return(c(introns, exons))
  
}