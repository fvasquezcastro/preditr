loadEditors <- function(editors_path, editors){
  
  if (!file.exists(editors_path)){
    
    logError("The editors file does not exist")
    stop()
  }
  
    
  editors_file <- read.csv(editors_path, header = TRUE, row.names = 1,
                           colClasses = "character", blank.lines.skip	= TRUE)

  for (e in editors) {
    
    if (any(rownames(editors_file) == e)){
      
      pam <- editors_file[e, "pam"]
      spacer_length <- as.numeric(editors_file[e, "spacer_length"])
      edit_type <- editors_file[e, "edit_type"]
      edit_window_min <- as.numeric(editors_file[e, "edit_window_min"])
      edit_window_max <- as.numeric(editors_file[e, "edit_window_max"])
      
      assign(e, createEditor(e, pam, spacer_length, edit_type, edit_window_min, edit_window_max), envir = .GlobalEnv)
      
    } else {
    
      logError(paste0("The editor ", e, " does not exist in ", editors_path))
      stop()
    }


  }
  
}

