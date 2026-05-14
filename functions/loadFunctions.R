loadFunctions <- function(){
  
  invisible(lapply(
    sort(list.files("functions", pattern="\\.R$", full.names=TRUE)),
    source
  ))    
  
}
