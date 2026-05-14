cleanLog <- function(session_tmp, job_name, output_path){
  
  log_table <- read.delim(
    file.path(session_tmp, paste0(job_name, ".log")),
    header = FALSE,
    quote = "",
    fill = TRUE,
    comment.char = ""
  )
  
  log_table$V2 <- NULL; log_table$V4 <- NULL; log_table$V5 <- NULL
  write.table(log_table, file = file.path(output_path, paste0(job_name, ".log")),
              row.names = FALSE, col.names = FALSE)
  
}