library(shiny)
library(bslib)
library(DT)
library(readr)
library(shinyjs)
library(shinybusy)

# Detect hosted vs local
hosted <- Sys.getenv("PREDITR_HOSTED", "FALSE") %in% c("TRUE", "true", "1")

if (hosted){
  hosted_threads <- as.numeric(Sys.getenv("PREDITR_THREADS", unset = 2))
}

ui <- navbarPage(
  title = NULL
  #div(
  #style = "display: flex; align-items: center;",
  #img(src = "preditr_logo.png", height = "40px", style = "margin-right: 10px;"),
  #),
  ,
  id = "main_navbar",
  theme = bslib::bs_theme(bootswatch = "flatly"),
  inverse = FALSE,
  fluid = TRUE,
  
  header = tagList(
    useShinyjs(),
    tags$head(
      
      #Load style sheet
      tags$link(rel = "stylesheet", type = "text/css", href = "ui.css"),
      
      tags$script(HTML(
        "
  document.addEventListener('click', async (e) => {
    if (e.target.closest('.copy-seq')) {
      const el = e.target.closest('.copy-seq');
      const text = el.dataset.seq;
      try {
        await navigator.clipboard.writeText(text);
        const icon = el.querySelector('i');
        const oldTitle = el.title;
        el.title = 'Copied!';
        icon.classList.replace('fa-clipboard', 'fa-check');
        setTimeout(() => {
          icon.classList.replace('fa-check', 'fa-clipboard');
          el.title = oldTitle;
        }, 1200);
      } catch (err) {
        console.error('Clipboard error', err);
      }
      e.preventDefault();
    }
  });
"
      )) 
    )
  ),
  
  # ---- Search Tab ----
  tabPanel(
    title = "Search",
    div(class = "container",
        
        # --- Logo ---
        div(style = "
                display: flex;
                justify-content: center;
                align-items: center;",
            img(src = "main_fig.png", 
                alt = "Graphical Abstract", 
                style = "max-width: 800px; height: auto; margin-left: 110px;"),
            
            
        ),
        
        # --- General Parameters ---
        div(class = "section-title", "General Parameters"),
        fluidRow(
          column(3, style = "text-align: center;",
                 selectInput("batch_organism", "Organism", choices = c("Human", "Mouse"))
          ),
          column(3, style = "text-align: center;",
                 textInput("batch_job_name", "Job Name")
          ),
          column(3, style = "text-align:center;",
                 selectInput("non_editing_controls", "Include Non-Editing Controls", choices = c("FALSE", "TRUE"))
          ),
          column(3, style = "text-align: center;",
                 numericInput("batch_threads", "Threads (Multiprocessing)", value = ifelse(hosted, hosted_threads, 2), min = 2)
          )
          
        ),
        
        uiOutput("hosted_message"),
        
        #--Off Targets
        div(class = "section-title", "Off-Target Search Parameters"),
        fluidRow(
          column(ifelse(hosted, 4, 3), style = "text-align: center;",
                 selectInput("off_targets", "Enable Off-Targets Search", choices = c("FALSE", "TRUE"))
          ),
          column(ifelse(hosted, 4, 3), style = "text-align: center;",
                 numericInput("batch_n_mismatches", "Max Mismatches", value = 3, min = 0, max = ifelse(hosted, 3, NA))
          ),
          column(ifelse(hosted, 4, 3), style = "text-align: center;",
                 numericInput("batch_n_max_alignments", "Max Alignments", value = 10, min = 1, max = ifelse(hosted, 10, NA))
          ),
          
          if (!hosted){
          column(3, style = "text-align: center;",
                 textInput("batch_genome_path", "Indexed Genome Directory")
          )}
          
        ),
        
        uiOutput("hosted_message_offtargets"),
        
        # --- Editors (File Upload) ---
        div(class = "section-title", "Editors"),
        div(style = "display: flex; justify-content: center;",
            fileInput("editors_file", "Choose Editors CSV File", accept = ".csv")),
        div(style = "display: flex; justify-content: center;",
            tags$a("Download Editors File Template (with examples)", href = "editors_example.csv", download = NA, style = "text-decoration: underline; color: blue; cursor: pointer;")
        ),
        
        # --- Targets (File Upload) ---
        div(class = "section-title", "Targets"),
        div(style = "display: flex; justify-content: center;",
            fileInput("batch_file", "Choose Targets CSV File", accept = ".csv")),
        div(style = "display: flex; justify-content: center;",
            tags$a("Download Targets File Template (with examples)", href = "targets_example.csv", download = NA, style = "text-decoration: underline; color: blue; cursor: pointer;")
        ),
        
        # --- Run Button ---
        div(class = "run-button-container",
            add_busy_spinner(spin = "fading-circle", color = "#007bff"),
            actionButton("run_batch_button", "Run Batch", class = "btn btn-primary run-button")
        ),
        
        # --- Post-run Buttons (Initially Hidden) ---
        div(class = "run-button-container",
            style = "margin-top: 15px; gap: 10px;",
            actionButton("view_results_button", "Load Results", class = "btn btn-secondary"),
            downloadButton("download_results", "Download Results (.csv)"),
            downloadButton("download_log", "Download Log (.log)")
        ),
        
        uiOutput("batch_progress_ui") #Displays progress bar
    )
  ),
  
  # ---- Explore Results Tab ----
  tabPanel(
    title = "Explore Results",
    value = "explore_results_tab",
    div(class = "container",
        div(class = "section-title", "Explore Results"),
        
        #Message to display at the start
        div(style = "text-align:center; color:gray; margin-bottom:10px;",
            textOutput("no_results_message")),
        
        fluidRow(
          column(12,
                 div(style = "display: flex; justify-content: flex-end; gap: 10px; margin-bottom: 10px;",
                     actionButton("load_example_output", "Load Example Output", class = "btn btn-secondary"),
                     actionButton("view_results_button2", "Load Results", class = "btn btn-secondary"),
                     downloadButton("download_results_tab", "Download Results (.csv)", class = "btn btn-primary"),
                     downloadButton("download_log_tab", "Download Log (.log)", class = "btn btn-primary")
                 ),
                 
                 #Show summary plot
                 div(
                   style = "text-align:center; margin-bottom:20px;",
                   imageOutput("results_svg", height = "auto")
                 ),
                 
                 #Buttons to filter results by color
                 div(style = "display:flex; justify-content:center; gap:10px; margin-bottom:10px;",
                     actionButton("show_all", "Show All", class = "btn btn-all-queries"),
                     actionButton("show_green", "Show Clean Guides", class = "btn btn-success"),
                     actionButton("show_orange", "Show Warned Guides", class = "btn btn-warning"),
                     actionButton("show_gray",  "Show Non-Editing",class = "btn btn-not-editing"),
                     actionButton("show_pink", "Show Not Found", class = "btn btn-not-found"),
                     actionButton("show_red", "Show Errors", class = "btn btn-error")
                 ),
                 
                 
                 
                 DTOutput("results_table")
          )
        )
    )
  ),
  
  # ---- Documentation Tab ----
  tabPanel(
    title = "Documentation",
    div(class = "container",
        
        # --- Main Title ---
        #div(class = "section-title", "PrEditR Documentation"),
        
        div(style = "
                display: flex;
                justify-content: center;
                align-items: center;",
            img(src = "preditr_logo.png", alt = "Graphical Abstract", style = "max-width: 400px; height: auto;"),
            
            
        ),
        
        div(style = "text-align:center; margin-bottom:25px;",
            p("A summary of the key parameters, input files, and outputs when using the PrEditR online. 
              For instructions on how to run PrEditR offline, refer to the ",
              tags$a(href = "https://github.com/fvasquezcastro/preditr",
                     target = "_blank",
                     style = "text-decoration: underline; color: #007bff;",
                     "complete documentation"),
              ".")
        ),
        
        tags$hr(style = "margin-top: 40px; margin-bottom: 25px; border-top: 2px solid #eee;"),
        
        # --- Input Parameters ---
        div(class = "subsection-title", "Input Parameters"),
        tags$ul(
          tags$li(HTML("<b>Organism:</b> Select <i>Human</i> or <i>Mouse</i>.")),
          tags$li(HTML("<b>Job Name:</b> An identifier for your run; used in output file names.")),
          tags$li(HTML("<b>Threads:</b> Number of parallel processes (default: 2). Increase only for large runs and if sufficient RAM is available.")),
          tags$li(HTML("<b>Off-Target Search:</b> Optional. Set to TRUE to search for potential off-target sites.")),
          tags$li(HTML("<b>Include Non-Editing Controls:</b> If set to TRUE, PrEditR will include all sgRNAs for each gene in the input file that do NOT produce an edit. (i.e., for an A-to-G editor, the sgRNA's edit window will NOT contain adenosines).")),
          tags$li(HTML("<b>Max Mismatches:</b> Number of allowed mismatches for off-target search (default: 3).")),
          tags$li(HTML("<b>Max Alignments:</b> Maximum number of genome alignments allowed before a guide is discarded (default: 10).")),
          
          if (Sys.getenv("PREDITR_HOSTED", "FALSE") %in% c("FALSE", "false", "0")) {
            tags$li(HTML("<b>Indexed Genome Directory:</b> Required only if off-target search is enabled. Must contain Bowtie1 <code>.ebwt</code> index files."))
          }
        ),
        
        tags$hr(style = "margin-top: 40px; margin-bottom: 25px; border-top: 2px solid #eee;"),
        
        # --- Editors File ---
        div(class = "subsection-title", "Editors File (editors.csv)"),
        p(HTML("This required CSV defines the properties of the base editors used for guide design. 
                Each row represents one base editor. A pre-formatted template can be downloaded directly from the Design tab.")),
        p(HTML("<b>Note:</b> The columns listed below are mandatory and reserved for input and internal use. 
               The editors file may include additional metadata columns (e.g., Addgene ID, notes), but their names must not conflict with the column names shown here.")),
        DT::datatable(
          data.frame(
            `Column` = c("name", "pam_sequence", "spacer_length", "edit_type", "edit_window_min", "edit_window_max"),
            `Description` = c(
              "Unique name for the editor.",
              "PAM sequence recognized by the nuclease (e.g., NGG). Use 'N' for any base.",
              "Length of the gRNA spacer sequence (usually 20).",
              "Type of base conversion performed by the editor (e.g., a2g, c2t, t2g).",
              "Position where the editable window begins, given in nucleotides upstream (5' end) of the PAM site. Must be a negative number.",
              "Position where the editable window ends, given in nucleotides upstream (5' end) of the PAM site. Must be a negative number and smaller (i.e., 'more negative') than edit_window_min. This is the furthermost position from the PAM site that is within the editor's edit window."
            )
          ),
          options = list(dom = 't', paging = FALSE),
          rownames = FALSE
        ),
        
        div(
          style = "
                display: flex;
                justify-content: center;
                align-items: center;
                margin-top: 30px;",
          img(src = "editors_help.svg", style = "max-width: 850px; height: auto;"),
          
          
        ),
        
        tags$hr(style = "margin-top: 40px; margin-bottom: 25px; border-top: 2px solid #eee;"),
        
        # --- Targets File ---
        div(class = "subsection-title", "Targets File (targets.csv)"),
        p(HTML("This required CSV specifies the genomic or protein targets for editing. Each row defines one editing task and links it to a specific editor.")),
        p(HTML("<b>Note:</b> The following columns are mandatory. 
                You may include additional metadata columns (e.g., sample ID, condition, notes), but their names must not conflict these or any column name reserved for the output.")),
        DT::datatable(
          data.frame(
            `Column` = c("gene_symbol", "ensembl_id", "uniprot_id", "target_aa", "target_position", "editor", "edit_type"),
            `Description` = c(
              "Official gene symbol (e.g., KRAS).",
              "Ensembl transcript ID (recommended for isoform-specific designs). Use only the ID portion (e.g., ENST00000256078) without the version suffix.",
              "UNIPROT ID of the target protein. Only reviewed UniProt IDs are supported.",
              "Single-letter amino acid code of the target residue (e.g., V for Valine).",
              "Numerical position of the amino acid within the protein sequence.",
              "Name of the base editor to use for this target (must match a 'name' from the editors file).",
              "Type of edit performed (e.g., a2g, c2t), matching the editor’s defined edit_type."
            )
          ),
          options = list(dom = 't', paging = FALSE),
          rownames = FALSE
        ),
        
        div(
          style = "text-align:center; margin-bottom:25px;",
          br(),
          p(
            strong("IMPORTANT CONSIDERATIONS:"), " ",
            "Users are only required to provide one ID (Ensembl or UniProt). However, when both Ensembl Transcript and UniProt IDs are provided for the same target (i.e., row in targets.csv), ",
            strong("Ensembl Transcript IDs are prioritized over UniProt IDs"),
            " because PrEditR queries genetic databases (i.e., if Ensembl and UniProt IDs do not match, ",
            em("PrEditR will use the Ensembl ID"),
            "). ",            
            "Only ",
            strong("reviewed UniProt IDs"),
            " are supported. PrEditR is isoform-aware; UniProt IDs should specify the correct isoform. If several are available for the same protein and the isoform is not indicated (e.g., simply P38398 instead of P38398-1), PrEditR will automatically search sgRNAs for the canonical Ensembl isoform.",
          )
        ),
        
        tags$hr(style = "margin-top: 40px; margin-bottom: 25px; border-top: 2px solid #eee;"),
        
        # --- Output Section ---
        div(class = "subsection-title", "Output Files"),
        p(HTML("PrEditR appends new annotation columns to your targets file when generating the output. 
                These columns are reserved and cannot be used as input column names in <code>targets.csv</code>.")),
        DT::datatable(
          data.frame(
            `Column` = c(
              "query_num","gene_strand", "sgRNA_seq", "percent_gc", "sgRNA_strand",
              "pam_seq", "chromosome", "pam_coordinates", "mutation_type",
              "wildtype_sequence", "mutant_sequence", "edits", "warnings", "error",
              "Restriction Enzymes", "Off-Target Alignments (n#)"
            ),
            `Description` = c(
              "The number of the input row that this output row corresponds to. Query numbers can be repeated in the output if multiple guides are found for the same target.",
              "Indicates gene strand (+ or -).",
              "The designed sgRNA sequence (always 5'->3').",
              "GC content (%) of the sgRNA.",
              "Strand of the sgRNA (+ or -).",
              "PAM sequence recognized for targeting. (5'->3')",
              "Gene chromosome",
              "Genomic coordinates of the PAM sequence.",
              "Type of predicted mutation (missense, nonsense, silent, etc.) assuming that any editable base in the edit window will be edited (100% editing efficiency for the edit window).",
              "Wild-type amino acid sequence around the target site (±7 residues). Vertical bars indicate the amino acids whose codons, fully or in part, fall within the edit window.",
              "Mutant amino acid sequence after editing (±7 residues).",
              "Concise notation of amino acid changes (e.g., S45P).",
              "Alerts users to potential undesired characteristics of the sgRNA (e.g., the edit window goes into an intron-exon junction, the edit will produce a nonsense mutation, ...)",
              "Alerts users to errors encountered during guide search (if any).",
              "Presence of restriction enzyme sites (EcoRI, KpnI, BsmBI, etc.) within the guide.",
              "Counts of alignments in the genome at n mismatches (i.e., n0 indicates the number of exact alignments to the genome; n2 indicates the number of alignments to the genome with 2 mismatches)."
            )
          ),
          options = list(dom = 't', paging = FALSE),
          rownames = FALSE
        ),
        
        tags$hr(style = "margin-top: 40px; margin-bottom: 25px; border-top: 2px solid #eee;"),
        
        
        # --- Notes ---
        div(class = "subsection-title", "Notes"),
        tags$ul(
          tags$li("Ensure that editor names used in the targets file exactly match those defined in the editors file."),
          tags$li("Avoid using reserved column names listed in the input or output sections for any custom metadata."),
          tags$li("For off-target analysis, download or prepare Bowtie1 indexed genomes (hg38 or mm10)."),
          tags$li("PAM site sequences must be given in the orientation 5'->3'."),
          tags$li("PAM sites are assumed to be located adjacent to the 3' side of the sgRNA sequences."),
          tags$li("Non-editing controls are excluded from off-target searches.")
        ),
        
        tags$hr(style = "margin-top: 40px; margin-bottom: 25px; border-top: 2px solid #eee;"),
        
        
        # --- Limitations of online version---
        div(class = "subsection-title", "Limitations of PrEditR Online"),
        tags$ul(
          tags$li("Access to computationally intensive features such as off-target searches and non-editing control design might be limited to ensure performance for all users."),
          tags$li("Input files are limited to 500 targets per job."),
          tags$li("It is not necessary to provide an indexed genome to run off-target searches online.")
          
        ),
        
        tags$hr(style = "margin-top: 40px; margin-bottom: 25px; border-top: 2px solid #eee;"),
        
        # --- General limitations of PrEditR---
        div(class = "subsection-title", "General Limitations of PrEditR"),
        tags$ul(
          tags$li("Only Human (hg38) and Mouse (mm10) genomes are currently supported. Support for additional species may be added in future releases."),
          tags$li("All results depend on user-supplied editor definitions. Incorrect PAM or edit window parameters may result in invalid designs."),
          tags$li("Off-target searches require properly indexed Bowtie1 genome directories; missing or corrupted indexes will cause failures."),
          tags$li("Results are limited by genome annotation completeness and accuracy in the reference genome version used."),
          tags$li("A greater number of threads will require more RAM. Avoid selecting more than 4-5 threads if your machine has less than 16 GB of RAM. If running the Shiny app using Docker Desktop, Docker usually caps the RAM that apps can access. Users can manually change this value."),
          tags$li("The command-line based version of PrEditR delivers better performance and uses lower RAM per thread than the Shiny app."),
          tags$li("While the sgRNA length can be varied by the user and users can design sgRNAs using multiple different editors in the same run, the sgRNA length per run must be the same across editors. If not, they must be separated into different runs.")
          
        ),
        
        
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
            
            # Text
            div(style = "font-size: 16px; text-align: left;",
                p(HTML(
                  '<br>
                  PrEditR was developed by the <a href="https://www.samyerslab.org" target="_blank">Myers Lab</a> at La Jolla Institute for Immunology to support CRISPR sgRNA design using custom base editors. 
          Originally created to streamline large-scale sgRNA design for protein post-translational modifications (PTMs) functional screens, PrEditR is a user-friendly tool for protein-centric base editing applications.'
                ))
            )
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
            
            a(
              href = "https://www.autoimmuneinstitute.org/", target = "_blank",  # open in new tab
              img(
                src = "gai_logo.png",
                alt = "GAI Logo",
                style = "max-width: 160px; height: auto;"
              )
            ),
            img(src = "nci_logo.png", alt = "NCI Logo", style = "max-width: 200px; height: auto;"),
            img(src = "ncats_logo.png", alt = "NCATS Logo", style = "max-width: 270px; height: auto;"),
            img(src = "nigms_logo.jpg", alt = "NIGMS Logo", style = "max-width: 290px; height: auto;")
        )
    )
  )
)
