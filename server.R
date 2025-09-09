library(shiny)
library(bslib)
library(DT)
library(readr)
library(shinyjs)
library(shinybusy)
library(promises)
library(future)

plan(multisession)

server <- function(input, output, session) {

  is_server <- Sys.getenv("SERVER", "FALSE") == "TRUE" #Environment variable to disable off-target searches for the online server version
  
  if (is_server) {
    disable("off_targets")
    disable("batch_n_mismatches")
    disable("batch_n_max_alignments")
    disable("batch_genome_path")
  }


  output$off_targets_message <- renderUI({
    if (is_server) {
      div(
        style = "color: red; margin-top: 10px; text-align: center;",
        "⚠️ Off-target searches are not supported in the online version. ",
        "Please download the local version to use this feature."
      )
    }
  })

  
  # --- GENERAL ---
  
  #Track the run state to prevent from concurrent runs
  is_running <- reactiveVal(FALSE)
  
  autoInvalidate <- reactiveTimer(500) #Refresh every half-second to track progress
  
  # Track number of processed rows
  progress_val <- reactiveVal(0)
  
  observe({
    autoInvalidate()
    progress_file <- file.path("shiny_tmp", "progress.txt")
    
    current <- if (file.exists(progress_file)) length(readLines(progress_file)) else 0
    if (current != progress_val()) {
      progress_val(current)
    }
  })
  
  
  # --- PROGRESS BAR ---
  # Batch progress bar UI
  output$batch_progress_ui <- renderUI({
    # req() ensures this doesn't render until a file is uploaded and we have a total.
    req(total_rows())
    
    # It's good practice to also require that the process is running before showing progress.
    # This requires the is_running() reactive value from the previous examples.
    req(is_running()) 
    
    current <- progress_val()
    
    # Prevent division by zero if total_rows() is somehow 0
    total <- max(1, total_rows())
    percent <- round((current / total) * 100)
    
    progress_text <- ""
    bar_html <- NULL
    
    if (percent >= 100) {
      # --- STATE 3: Process is 100% done, now in final steps ---
      progress_text <- "Wrapping up..."
      
      # Show a solid, pulsing, or different colored bar for the final step
      bar_html <- div(style = "height: 25px; background-color: #e9ecef; border-radius: 5px;",
                      div(style = "width: 100%; height: 100%; background-color: #28a745; border-radius: 5px; transition: background-color 0.5s ease;")) # Green color for 'done'
      
    } else if (current == 0) {
      # --- STATE 1: Process has started, but no rows processed yet ---
      progress_text <- "Loading (this might take a while)..."
      
      # Show an empty bar
      bar_html <- div(style = "height: 25px; background-color: #e9ecef; border-radius: 5px;",
                      div(style = "width: 0%; height: 100%; background-color: #007bff; border-radius: 5px;"))
      
    } else {
      # --- STATE 2: Normal progress tracking ---
      progress_text <- paste0(current, " of ", total_rows(), " rows processed (", percent, "%)")
      
      # The standard progress bar
      bar_html <- div(style = "height: 25px; background-color: #e9ecef; border-radius: 5px;",
                      div(style = paste0("width:", percent, "%; height: 100%; background-color: #007bff; border-radius: 5px; transition: width 0.5s ease-in-out;")))
    }
    
    # Assemble the final UI
    tagList(
      h4("Progress"),
      bar_html,
      p(strong(progress_text))
    )
  })
  
  
  # --- BATCH MODE ---
  
  # Count rows in uploaded batch file
  total_rows <- reactive({
    req(input$batch_file)
    df <- read.csv(input$batch_file$datapath, fill = TRUE)
    nrow(df)
  })
  
  observeEvent(input$run_batch_button, {
    
    if (is_running()) return(NULL)  # Prevent re-entry
    is_running(TRUE)  # Set flag to running
    shinyjs::disable("run_batch_button") #Disable the button visually
    
    if (input$off_targets){
      req(input$batch_file, input$editors_file, input$batch_job_name, input$batch_genome_path,
          input$batch_organism)
    } else {
      req(input$batch_file, input$editors_file, input$batch_job_name,
          input$batch_organism)
    }

    
    progress_file <- file.path("/home","tmp", "progress.txt")
    if (file.exists(progress_file)) file.remove(progress_file)
    
    #Read all reactive values into local variables before passing them to a new session
    batch_file_path <- input$batch_file$datapath
    job_name        <- input$batch_job_name
    editors_path    <- input$editors_file$datapath
    organism        <- tolower(input$batch_organism)
    mismatches      <- input$batch_n_mismatches
    max_alignments  <- input$batch_n_max_alignments
    genome_path     <- file.path("/data", input$batch_genome_path)
    threads         <- input$batch_threads
    off_targets     <- input$off_targets
    flanking3       <- ""
    flanking5       <- ""
    tmp_folder      <- "/data"
    
    #Run the tool. Assumes that the local path is bound to /data in the container
    # --- ASYNCHRONOUS CALL ---
    # Now, the future uses the local variables, not the reactive 'input$' values.
    future_promise({
      system2("Rscript",
              args = c("/home/PrEditR.R",
                       "--input", batch_file_path,  
                       "--job_name", job_name,     
                       "--editors", editors_path,   
                       "--output", "/data",
                       "--organism", organism,
                       "--n_mismatches", mismatches,
                       "--n_max_alignments", max_alignments,
                       "--indexed_genome", genome_path,
                       "--threads", threads,
                       "--shiny", TRUE,
                       "--off_targets", off_targets,
                       "--tmp", tmp_folder),
              stdout = "",
              stderr = "",  
              wait = TRUE)
    }) %...>% (function(exit_code) {
      # This block executes when the promise resolves (i.e., the script finishes)
      if (exit_code == 0) {
        showModal(modalDialog(
          title = "Run Complete",
          "Your analysis has finished successfully.",
          easyClose = TRUE,
          footer = modalButton("OK")
        ))
      } else {
        showModal(modalDialog(
          title = "Error",
          "An unexpected error was encountered. Check the log file for details. Try running again with less threads if an out-of-memory error was encountered.",
          easyClose = FALSE,
          footer = modalButton("Dismiss")
        ))
        stopApp()
      }
    }) %...>% (function(.) {
      # This acts like a 'finally' block
      is_running(FALSE)
      shinyjs::enable("run_batch_button")
      
      # Clean-up
      if (file.exists(progress_file)) {
        file.remove(progress_file)
      }
    })
    
    # Return something non-NULL to keep the observer from stopping
    if (file.exists(progress_file)) file.remove(progress_file)
    progress_val(0)
    return(NULL)
  })
  
}