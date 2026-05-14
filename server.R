source("PrEditR.R")

library(shiny)
library(shinyjs)
library(future)
library(promises)
library(progressr)

server <- function(input, output, session) {
  
  # --- CLEANUP ---
  # Clear any residual loggers on new session start (best practice)
  try({
    ParallelLogger::clearLoggers()
  }, silent = TRUE)
  
  # --- GENERAL SETUP ---
  # 'hosted' and related flags are now inherited from global.R
  if (hosted) {
    
    if (!allow_off_targets){
      disable("off_targets")
      disable("batch_n_mismatches")
      disable("batch_n_max_alignments")
    }
    
    if (!allow_off_targets_finetuning){
      disable("batch_n_mismatches")
      disable("batch_n_max_alignments")
    }
    
    if (!allow_non_editing){
      disable("non_editing_controls")
    }
    
    disable("batch_threads")
    
    # Also disable the indexed genome button to avoid confusion since it is not needed online
    shinyjs::hide("batch_genome_path")
  }
  
  # Welcome message
  observe({
    if (hosted) {
      showModal(modalDialog(
        title = "Welcome to PrEditR!",
        HTML("
        <div style='display: flex; align-items: flex-start; gap: 15px;'>
          
          <!-- Clickable LJI logo on the left -->
          <a href='https://www.lji.org' target='_blank' style='text-decoration: none;'>
            <img src='lji_logo.png' alt='LJI Logo' style='height: 80px; margin-top: 25px;'/>
          </a>
          
          <!-- Text on the right -->
          <div style='font-size: 16px; line-height: 1.5;'>
            PrEditR was developed by the 
            <a href='https://www.samyerslab.org' target='_blank'
               style='color: #13989f; font-weight: 600; text-decoration: none;'>
               Myers Lab
            </a>
            at the La Jolla Institute for Immunology (LJI) and is free to use both online and locally.<br><br>
            PrEditR does not use cookies, and all files are permanently removed upon session end.
          </div>
        </div>
      "),
        easyClose = TRUE,
        footer = modalButton("Ok!")
      ))
    }
  })
  
  # Rendering DT table UI
  observe({
    shinyjs::runjs("
    const style = document.createElement('style');
    style.innerHTML = `
      table.dataTable tbody tr {
        border-radius: 12px !important;
        margin-bottom: 8px !important;
        box-shadow: 0 1px 4px rgba(0,0,0,0.08);
        background-clip: padding-box;
      }
      table.dataTable tbody tr td {
        border: none !important;
        padding: 10px 14px !important;
      }
      table.dataTable tbody tr {
        border-spacing: 0 10px;
      }
      table.dataTable tbody {
        border-collapse: separate !important;
      }
    `;
    document.head.appendChild(style);
  ");
  })
  
  # --- INITIALIZATION ---
  is_running <- reactiveVal(FALSE)
  session_folder <- normalizePath(file.path("tmp", paste0("preditr_", session$token)), mustWork = FALSE)
  dir.create(session_folder, recursive = TRUE, showWarnings = FALSE)
  output_folder <- session_folder
  
  # Hide or disable UI elements at start
  shinyjs::hide("view_results_button")
  shinyjs::hide("download_results")
  shinyjs::hide("download_log")
  shinyjs::hide("download_results_tab")
  shinyjs::hide("download_log_tab")
  shinyjs::hide("view_results_button2")
  shinyjs::hide("show_all")
  shinyjs::hide("show_green")
  shinyjs::hide("show_orange")
  shinyjs::hide("show_gray")
  shinyjs::hide("show_pink")
  shinyjs::hide("show_red")
  
  # --- DOWNLOAD HANDLER HELPER ---
  make_download_handler <- function(path_expr) {
    downloadHandler(
      filename = function() {
        p <- tryCatch(path_expr(), error = function(e) NULL)
        if (!is.null(p) && nzchar(p) && file.exists(p)) basename(p)
        else NULL  # prevents any download if no valid file
      },
      content = function(file) {
        p <- tryCatch(path_expr(), error = function(e) NULL)
        if (is.null(p) || !nzchar(p) || !file.exists(p)) return(invisible(NULL))
        file.copy(p, file, overwrite = TRUE)
      }
    )
  }
  
  # --- REACTIVE VALUES ---
  results_path <- reactiveVal(NULL)
  log_path <- reactiveVal(NULL)
  latest_results_path <- reactiveVal(NULL)
  latest_log_path <- reactiveVal(NULL)
  pretty_results_path <- reactiveVal(NULL) #This is for the table, not the plot!
  full_df <- reactiveVal(NULL)
  filtered_df <- reactiveVal(NULL)
  organism_val <- reactiveVal("Human") # Global organism reactive value. By default Human because the example output is for human 
  
  # --- DOWNLOAD HANDLERS ---
  output$download_results <- make_download_handler(results_path)
  output$download_log <- make_download_handler(log_path)
  output$download_results_tab <- make_download_handler(results_path)
  output$download_log_tab <- make_download_handler(log_path)
  
  # --- VIEW RESULTS TAB SETUP ---
  
  # Empty message for startup
  output$no_results_message <- renderText({
    if (is.null(results_path())) {
      "No results loaded yet. Click 'Load Example Output' or run a job to view results. Example results
      can only be loaded when no job is running."
    } else ""
  })
  
  
  # Load example output (only table, downloads remain disabled)
  observeEvent(input$load_example_output, {
    example_path <- normalizePath(file.path("www", "example_output.csv"), mustWork = TRUE)
    results_path(example_path)
    pretty_results_path(file.path("www/example_interactive_results.rds"))
    
    organism_val("Human") #Example dataset is human
    updateTabsetPanel(session, "main_navbar", selected = "Explore Results")
    update_filtered_df() #To restore all colors when clicking load example after doing color filtering
    
    shinyjs::show("show_all")
    shinyjs::show("show_green")
    shinyjs::show("show_orange")
    shinyjs::show("show_gray")
    shinyjs::show("show_pink")
    shinyjs::show("show_red")
    
    output$results_svg <- renderImage({
      list(
        src = "www/example_summary_plot.svg",   
        contentType = "image/svg+xml",
        width = "40%",
        height = "auto"
      )
    }, deleteFile = FALSE)
    
    showNotification("Example output loaded.", type = "message")
  })
  
  
  # --- FILTER RESULTS BY COLOR (MUST BE BEFORE output$results_table)
  update_filtered_df <- function() {
    p_pretty <- pretty_results_path()
    p_csv <- results_path()
    
    if (!is.null(p_pretty) && file.exists(p_pretty)) {
      df <- tryCatch(readRDS(p_pretty), error = function(e) NULL)
    } else if (!is.null(p_csv) && file.exists(p_csv)) {
      df <- tryCatch(readr::read_csv(p_csv, show_col_types = FALSE), error = function(e) NULL)
    } else {
      df <- NULL
    }
    
    if (is.null(df)) {
      full_df(NULL)
      filtered_df(NULL)
      return()
    }
    
    # Ensure columns exist
    for (col in c("protospacer_seq", "mutation_type", "warnings")) {
      if (!col %in% names(df)) df[[col]] <- NA_character_
    }
    
    # Store both
    full_df(df)
    filtered_df(df)
  }
  
  observeEvent(input$show_all, {
    df <- full_df()
    if (!is.null(df)) filtered_df(df)
  })
  
  observeEvent(input$show_green, {
    df <- full_df()
    if (!is.null(df)) filtered_df(dplyr::filter(df, row_color == "#E9F7F1"))
  })
  
  observeEvent(input$show_orange, {
    df <- full_df()
    if (!is.null(df)) filtered_df(dplyr::filter(df, row_color == "#FFF6E8"))
  })
  
  observeEvent(input$show_pink, {
    df <- full_df()
    if (!is.null(df)) filtered_df(dplyr::filter(df, row_color == "#FBE9EE"))
  })
  
  observeEvent(input$show_gray, {
    df <- full_df()
    if (!is.null(df)) filtered_df(dplyr::filter(df, row_color == "#F7F7F7"))
  })
  
  observeEvent(input$show_red, {
    df <- full_df()
    if (!is.null(df)) filtered_df(dplyr::filter(df, row_color == "#F6DEE6"))
  })
  
  # --- RESULTS TABLE: searchable, filterable, sortable, col visibility ---
  output$results_table <- renderDT({
    df <- filtered_df()
    if (is.null(df)) {
      return(DT::datatable(
        data.frame(),
        options = list(dom = 't', paging = FALSE),
        rownames = FALSE
      ))
    }
    
    #Default columns to show
    default_visible_cols <- c("query_num", "gene_symbol", "ensembl_id","uniprot_id","target_aa", "target_position",
                              "protospacer_seq", "mutation_type", "edits", "warnings", "error")
    
    hidden_cols <- which(!names(df) %in% default_visible_cols) - 1
    color_col_idx <- which(names(df) == "row_color") - 1
    
    # Force numeric columns to be shown and filtered as plain integer text
    num_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    df[num_cols] <- lapply(df[num_cols], function(x) {
      # round, drop NA, and make character so DT can't invoke numeric plugin
      ifelse(is.na(x), "", as.character(round(x)))
    })
    
    #Re-label columns
    col_labels <- c(
      query_num = "Query #",
      gene_symbol = "Gene Symbol",
      ensembl_id = "Ensembl ID",
      uniprot_id = "UniProt ID",
      target_aa = "AA",
      target_position = "Position",
      editor = "Editor",
      edit_type = "Edit Type",
      gene_strand = "Gene Strand",
      protospacer_seq = "Protospacer Sequence",
      percent_gc = "GC %",
      protospacer_strand = "Protospacer Strand",
      pam_seq = "PAM Sequence",
      chromosome = "Chromosome",
      pam_coordinates = "PAM Coordinates",
      mutation_type = "Mutation Type",
      wildtype_sequence = "Wildtype AA Sequence",
      mutant_sequence = "Mutant AA Sequence",
      edits = "Edits",
      warnings = "Warnings",
      error = "Errors",
      EcoRI = "EcoRI",
      KpnI = "KpnI",
      BsmBI = "BsmBI",
      BsaI = "BsaI",
      BbsI = "BbsI",
      PacI = "PacI",
      MluI = "MluI"
    )
    
    datatable(
      df,
      rownames = FALSE,
      colnames = ifelse(names(df) %in% names(col_labels), col_labels[names(df)], names(df)),
      selection = "none",
      filter = "top",
      extensions = c("Buttons", "FixedHeader", "ColReorder"),
      options = list(
        dom = "Bfrtip",
        buttons = list(list(
          extend = "colvis",
          text = "Columns",
          columns = ":not(:last-child)"
        )),
        ordering = TRUE,
        orderMulti = TRUE,
        searchHighlight = TRUE,
        fixedHeader = TRUE,
        scrollX = TRUE,
        scrollY = "70vh",
        scroller = TRUE,
        autoWidth = FALSE,
        colReorder = TRUE,
        paging = FALSE, 
        deferRender = TRUE,
        columnDefs = list(
          list(targets = hidden_cols, visible = FALSE),
          list(targets = color_col_idx, visible = FALSE)
        )
      ),
      class = "compact hover nowrap",
      escape = FALSE
    ) |>
      formatStyle(
        columns = names(df)[names(df) != "row_color"],
        valueColumns = "row_color",
        backgroundColor = styleEqual(
          c("#E9F7F1", "#FBE9EE", "#F7F7F7", "#FFF6E8"),
          c("#E9F7F1", "#FBE9EE", "#F7F7F7", "#FFF6E8")
        ),
        color = "black",
        whiteSpace = "normal",
        wordWrap = "break-word"
      )
  })
  
  # --- MAIN RUN LOGIC ---
  # Check file size as soon as it is uploaded
  row_count <- reactiveVal(NULL) #Global to be accessed later by observeEvent input$run_batch_button
  
  observeEvent(input$batch_file, {
    # Input check
    n_rows <- length(readr::read_lines(input$batch_file$datapath))
    row_count(n_rows)
    
    # max_input_rows is defined in global.R
    if (hosted && (n_rows - 1 > max_input_rows)) {
      showModal(modalDialog(
        title = "Too many rows",
        paste0("Your file has ", n_rows - 1, " data rows, but the maximum allowed in the online version is ", max_input_rows, ". To process any file size, please use the local version."),
        easyClose = TRUE,
        footer = modalButton("Dismiss")
      ))
      shinyjs::reset("batch_file")
    }
  })
  
  observeEvent(input$run_batch_button, {
    
    shinyjs::hide("view_results_button")
    shinyjs::hide("download_results")
    shinyjs::hide("download_log")
    shinyjs::hide("download_results_tab")
    shinyjs::hide("download_log_tab")
    shinyjs::hide("view_results_button2")
    shinyjs::disable("load_example_output")
    
    if (is_running()) return(NULL)
    shinyjs::disable("run_batch_button")
    req(input$editors_file, input$batch_file)
    
    job_name <- isolate(input$batch_job_name)
    organism <- isolate(tolower(input$batch_organism))
    organism_val(ifelse(organism == "Mouse", "mouse", "human")) 
    n_mismatches <- isolate(input$batch_n_mismatches)
    n_max_alignments <- isolate(input$batch_n_max_alignments)
    off_targets <- isolate(input$off_targets)
    non_editing_controls <- isolate(input$non_editing_controls)
    # hosted_threads is defined in global.R
    threads <- isolate(ifelse(hosted, hosted_threads, input$batch_threads))
    
    #Delete files from previous jobs, if any
    #Even though the tmp directory is linked to a unique session token, users might submit one job after another in the same session (i.e., without reloading the app)
    #When this happens, logs get concatenated in the same file
    unlink(list.files(output_folder, full.names = TRUE, recursive = TRUE), recursive = TRUE)
    
    # Copy uploaded files
    batch_file_path <- file.path(output_folder, basename(input$batch_file$name))
    file.copy(input$batch_file$datapath, batch_file_path, overwrite = TRUE)
    editors_path <- file.path(output_folder, basename(input$editors_file$name))
    file.copy(input$editors_file$datapath, editors_path, overwrite = TRUE)
    
    if (hosted){
      if (allow_off_targets){
        organism_paths <- c(Human = "hg38_genome_index", Mouse = "mm10_genome_index")
        # hosted_indexed_genomes_path is defined in global.R
        genome_path <- file.path(hosted_indexed_genomes_path, organism_paths[organism])
      } else {
        
        genome_path <- output_folder #just a place holder because the value cannot be empty but they are deactivated
      }
    } else {
      genome_path <- file.path("/data", input$batch_genome_path)
    }
    
    is_running(TRUE)
    
    ui_workers <- 1
    
    #Nested future plan to keep the UI responsive while the actual processing happens
    future::plan(list(
      future::tweak(future::multicore, workers = ui_workers),
      future::tweak(future::multicore, workers = threads - ui_workers)
    ))
    
    
    total_steps <- ceiling(row_count()*1.5 + 3 + as.integer(hosted))
    Sys.setenv(PREDITR_STEPS = as.character(total_steps))
  
    # ASYNC EXECUTION
    progressr::withProgressShiny(message = "Status", value = 0, {
      progressr::with_progress({
        p <- progressr::progressor(steps = total_steps)
        p(message = "Initializing...")
        
        future_promise({
          exit_code <- runPrEditR(
            input_file = batch_file_path,
            job_name = job_name,
            editors_path = editors_path,
            output_path = output_folder,
            organism = organism,
            indexed_genome = genome_path,
            n_mismatches = n_mismatches,
            n_max_alignments = n_max_alignments,
            flanking5 = "",
            flanking3 = "",
            threads = threads,
            shiny = TRUE,
            off_targets = off_targets,
            non_editing_controls = non_editing_controls,
            tmp = output_folder,
            debug = (Sys.getenv("PREDITR_DEBUG") == "TRUE"),
            progressor = p   
          )
          exit_code
        }) %...>% (function(exit_code) {
          log_file <- file.path(output_folder, paste0(job_name, ".log"))
          log_path(log_file)
          
          if (exit_code == 0) {
            shinyjs::show("view_results_button")
            shinyjs::show("download_results")
            shinyjs::show("download_log")
            shinyjs::show("download_results_tab")
            shinyjs::show("download_log_tab")
            shinyjs::show("view_results_button2")
            shinyjs::enable("load_example_output")
            
            results_path(file.path(output_folder, paste0(job_name, "_results.csv")))
            pretty_results_path(file.path(output_folder, paste0(job_name, "_interactive_results.rds")))
            
            showNotification("Run completed successfully.", type = "message")
          } else {
            showModal(modalDialog(
              title = "Execution Failed",
              tagList(
                p("A critical error occurred."),
                div(style = "text-align: center;", downloadButton("download_log", "Download Log"))
              ),
              easyClose = FALSE
            ))
            shinyjs::enable("load_example_output")
          }
        }) %...!% (function(e) {
          showNotification(paste("Error:", conditionMessage(e)), type = "error")
        }) %...>% (function(.) {
          is_running(FALSE)
          shinyjs::enable("run_batch_button")
          shinyjs::enable("load_example_output")
        })
      })
    }, session = session)
  })
  
  
  
  # --- NAVIGATION OBSERVERS ---
  observeEvent(input$view_results_button, {
    results_path(file.path(output_folder, paste0(input$batch_job_name, "_results.csv")))
    pretty_results_path(file.path(output_folder, paste0(input$batch_job_name, "_interactive_results.rds")))
    update_filtered_df()
    
    shinyjs::show("show_all")
    shinyjs::show("show_green")
    shinyjs::show("show_orange")
    shinyjs::show("show_gray")
    shinyjs::show("show_pink")
    shinyjs::show("show_red")
    
    output$results_svg <- renderImage({
      plot_path <- file.path(output_folder, paste0(input$batch_job_name, "_summary_plot.svg"))
      if (!file.exists(plot_path)) {
        showNotification("No summary plot found in output folder.", type = "warning")
        return(NULL)
      }
      list(
        src = plot_path,
        contentType = "image/svg+xml",
        width = "40%",
        height = "auto"
      )
    }, deleteFile = FALSE)
    
    showNotification("Displaying latest job results.", type = "message")
    updateNavbarPage(session, "main_navbar", selected = "explore_results_tab")
  })
  
  # --- LOAD JOB RESULTS BACK (Useful when the example results were loaded and the user wants to go back to their results) ---
  observeEvent(input$view_results_button2, {
    results_path(file.path(output_folder, paste0(input$batch_job_name, "_results.csv")))
    pretty_results_path(file.path(output_folder, paste0(input$batch_job_name, "_interactive_results.rds")))
    update_filtered_df()
    
    # Show results plot if available
    output$results_svg <- renderImage({
      plot_path <- file.path(output_folder, paste0(input$batch_job_name, "_summary_plot.svg"))
      if (!file.exists(plot_path)) {
        showNotification("No summary plot found in output folder.", type = "warning")
        return(NULL)
      }
      list(
        src = plot_path,
        contentType = "image/svg+xml",
        width = "40%",
        height = "auto"
      )
    }, deleteFile = FALSE)
    
    showNotification("Displaying latest job results.", type = "message")
  })
  
  # --- CLEANUP ---
  session$onSessionEnded(function() {
    unlink(file.path("tmp", paste0("preditr_", session$token)), recursive = TRUE, force = TRUE)
  })
}
