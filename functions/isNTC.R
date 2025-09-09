isNTC <- function(protospacer, target_base, editing_window, spacer_len){
  #Protospacer sequences are given in 5'->3' direction regardless
  #of the strand
    
    edit_window_seq <- substr(protospacer, spacer_len-max(abs(editing_window))+1,
                              spacer_len-min(abs(editing_window))+1)
    
    if (grepl(toupper(target_base), toupper(edit_window_seq))) {
      
      return(FALSE)
      
    } else {
      
      return(TRUE)
    }
  
}