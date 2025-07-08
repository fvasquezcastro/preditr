createEditor <- function(editor_name, pam, spacer_length, edit_type, edit_window_min, edit_window_max){
  

    nuclease <- CrisprNuclease(paste0(editor_name, "_nuclease"),
                               targetType = "DNA",
                               pams = c(paste0("(", nchar(pam), "/", nchar(pam), ")", pam)),
                               weights = c(1),
                               pam_side = "3prime",
                               spacer_length = spacer_length)
    

  
  weights <- data.frame(
    positions = edit_window_max:-1,
    C2A = rep(0, abs(edit_window_max)),
    C2G = rep(0, abs(edit_window_max)),
    C2T = rep(0, abs(edit_window_max)),
    G2A = rep(0, abs(edit_window_max)),
    G2C = rep(0, abs(edit_window_max))
  )
  
  condition <- weights$positions <= edit_window_min & weights$positions >= edit_window_max
  
  weights[condition, toupper(edit_type)] <- 1
  weights[!condition, toupper(edit_type)] <- 0

  weights <- as.matrix(weights)
  weights <- t(weights)
  
  new_colnames <- weights[1,]
  colnames(weights) <- new_colnames
  weights <- weights[-1, ]
  
  
  editor <- BaseEditor(nuclease, baseEditorName=editor_name, editingWeights = weights)

  
  return(editor)
}