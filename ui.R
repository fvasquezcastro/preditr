library(shiny)
library(bslib)
library(DT)
library(readr)
library(shinyjs)
library(shinybusy)

ui <- navbarPage(
  title = NULL,
  id = "main_navbar",
  theme = bslib::bs_theme(bootswatch = "flatly"),
  inverse = FALSE,
  fluid = FALSE,
  
  header = tagList(
    useShinyjs(),
    tags$head(
      tags$style(HTML("
        body {
          background-color: white;
          color: black;
        }
        .navbar {
          background-color: #f8f9fa;
        }
        .navbar .navbar-nav > li > a {
          color: black !important;
        }
        .tab-content {
          padding: 20px;
        }
        .form-group label {
          color: black;
          display: flex;
          justify-content: center;
        }
        .form-group .form-control {
          margin-left: auto;
          margin-right: auto;
          text-align: center;
        }
        .numeric-input, .select-input, .text-input {
          display: flex !important;
          justify-content: center !important;
          margin-left: auto !important;
          margin-right: auto !important;
          text-align: center !important;
        }
        .btn-primary {
          background-color: black;
          border-color: black;
          color: white;
        }
        .btn-primary:hover {
          background-color: gray;
          border-color: gray;
          color: white;
        }
        .section-title {
          font-size: 28px;
          font-weight: bold;
          margin-top: 40px;
          margin-bottom: 20px;
          text-align: center;
        }
        .logo-container {
          text-align: center;
          margin-top: 20px;
          margin-bottom: 20px;
        }
        .logo-container img {
          max-height: 150px;
          height: auto;
        }
        .left-button {
          text-align: left;
          margin-top: 20px;
        }
        .run-button-container {
          display: flex;
          justify-content: center;
          margin-top: 30px;
        }
        .run-index-button {
          display: flex;
          justify-content: center;
          margin-top: 30px;
        }
      "))
    )
  ),
  # ---- Batch Mode Tab ----
  tabPanel(
    title = "Design",
    div(class = "container",
        
        # --- Logo ---
        div(class = "logo-container",
            img(src = "preditr_logo.png", alt = "Logo")
        ),
        
        # --- General Parameters ---
        div(class = "section-title", "General Parameters"),
        fluidRow(
          column(4, style = "text-align: center;",
                 selectInput("batch_organism", "Organism", choices = c("Human", "Mouse"))
          ),
          column(4, style = "text-align: center;",
                 textInput("batch_job_name", "Job Name")
          ),
          column(4, style = "text-align: center;",
                 numericInput("batch_threads", "Threads", value = 1, min = 1)
          )
          
        ),
        
        #--Off Targets
        div(class = "section-title", "Off-Target Search Parameters"),
        fluidRow(
          column(3, style = "text-align: center;",
                        selectInput("off_targets", "Enable Off-Targets Search", choices = c("FALSE", "TRUE"))
          ),
          column(3, style = "text-align: center;",
                 numericInput("batch_n_mismatches", "Mismatches", value = 3, min = 0)
          ),
          column(3, style = "text-align: center;",
                 numericInput("batch_n_max_alignments", "Alignments", value = 10, min = 1)
          ),
          column(3, style = "text-align: center;",
                 textInput("batch_genome_path", "Indexed Genome Directory")
          ),
        
        ),
        
        uiOutput("off_targets_message"),
        
        # --- Editors (File Upload) ---
        div(class = "section-title", "Editors"),
        div(style = "display: flex; justify-content: center;",
            fileInput("editors_file", "Choose Editors CSV File", accept = ".csv")),
        div(style = "display: flex; justify-content: center;",
            tags$a("Download Editors File Template", href = "editors_template.csv", download = NA, style = "text-decoration: underline; color: blue; cursor: pointer;")
        ),
        
        # --- Targets (File Upload) ---
        div(class = "section-title", "Targets"),
        div(style = "display: flex; justify-content: center;",
            fileInput("batch_file", "Choose Targets CSV File", accept = ".csv")),
        div(style = "display: flex; justify-content: center;",
            tags$a("Download Targets File Template", href = "targets_template.csv", download = NA, style = "text-decoration: underline; color: blue; cursor: pointer;")
        ),
        
        # --- Run Button ---
        div(class = "run-button-container",
            add_busy_spinner(spin = "fading-circle", color = "#007bff"),
            actionButton("run_batch_button", "Run Batch", class = "btn btn-primary run-button")
        ),
        
      uiOutput("batch_progress_ui") #Displays progress bar
    )
  ),
  
  # ---- About Tab ----
  tabPanel(
    title = "About",
    div(class = "container",
        
        # --- About Us Section ---
        div(class = "section-title", "About PrEditR"),
        div(style = "
                display: flex;
                justify-content: center;
                align-items: center;
                gap: 20px;
                max-width: 900px;
                margin: 0 auto;
                padding: 10px 0;
                
            ",
            # Logo on the left
            img(src = "lji_logo.png", alt = "LJI Logo", style = "max-width: 125px; height: auto;"),
            
            # Text on the right
            div(style = "font-size: 16px; text-align: left;",
                p(HTML(
                  '<br>
                  PrEditR was developed by the <a href="https://www.samyerslab.org" target="_blank">Myers Lab</a> at La Jolla Institute for Immunology to support CRISPR sgRNA design using custom base editors. 
          Originally created to streamline large-scale sgRNA design for protein post-translational modifications (PTMs) functional screens, PrEditR is a use-friendly tool for protein-centric base editing applications.'
                ))
            )
        ),
        
        # --- Documentation Section ---
        div(class = "section-title", "Documentation"),
        div(style = "text-align: center; margin-bottom: 30px; font-size: 16px;",
            p("Full documentation is available ",
              tags$a(href = "https://github.com/fvasquezcastro/preditr",
                     target = "_blank",
                     style = "text-decoration: underline; color: #007bff;",
                     "here"),
              ".")
        ),
        
        # --- Funding Acknowledgements Section ---
        div(class = "section-title", "Funding Acknowledgements"),
        
        div(class = "logo-container", style = "
            display: flex;
            justify-content: center;
            align-items: center;
            flex-wrap: wrap;
            gap: 20px;
            padding: 10px 0;
            ",
            
            img(src = "gai_logo.png", alt = "GAI Logo", style = "max-width: 160px; height: auto;"),
            img(src = "nci_logo.png", alt = "NCI Logo", style = "max-width: 200px; height: auto;"),
            img(src = "ncats_logo.png", alt = "NCATS Logo", style = "max-width: 270px; height: auto;"),
            img(src = "nigms_logo.jpg", alt = "NIGMS Logo", style = "max-width: 290px; height: auto;")
        )
    )
  )
)
