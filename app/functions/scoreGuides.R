scoreGuides <- function(guideSet, flanking5, flanking3){
  
  
  if (flanking5 != "" & flanking3 != ""){
    
    guideSet <- addRestrictionEnzymes(guideSet, flanking5, flanking3) #Allows to search for enzyme restriction sites that can form when the flanking sequences for delivery are appended to the spacer
  }
  else {
    
    guideSet <- addRestrictionEnzymes(guideSet)
  }
  
  
  return(guideSet)
  
  
}