# PrEditR Documentation

This guide provides instructions for running PrEditR, either through the user-friendly Shiny interface or via the command line.

## Shiny App Version

This section will walk you through setting up and running the PrEditR Shiny app on your local machine using the Docker Desktop graphical user interface (GUI).

### 1. System Architecture

First, you'll need to know your computer's chip architecture to download the correct Docker image. Here’s a quick guide:

* **`amd64`** (also known as `x86-64`): This architecture is used by most desktop and laptop computers with processors from Intel and AMD.
* **`arm64`** (also known as `AArch64`): This architecture is common in mobile devices and is now used in newer laptops, including Apple's M-series chips and some Windows devices with Snapdragon processors.

### 2. Getting Started with Docker

PrEditR is packaged in a Docker container, which makes it easy to run on any system with a simple graphical interface.

#### Step 1: Install Docker Desktop

If you don't already have it, download and install Docker Desktop from the official Docker website. It's available for Windows, Mac, and Linux. A computer restart will be needed.

#### Step 2: Download the PrEditR Image using Docker Desktop (No Account Needed!)

You do not need a Docker Hub account to download and run PrEditR, as the image is publicly available.

1.  Open the Docker Desktop application.
2.  In the search bar at the top of the window, type `fvasquezcastro/preditr` and press Enter.
3.  From the search results, select the `fvasquezcastro/preditr` image.
4.  On the right side of the screen, you will see a **Tag** dropdown menu. It is crucial to select the correct tag for your system's architecture:
    * `v3_amd64` for Intel/AMD systems.
    * `v3_arm64` for Apple M-series/Snapdragon systems.
5.  You will now see two options: **Pull** and **Run**.
    * **Pull**: This action downloads the image to your computer, where it will be stored locally. You can find it in the `Images` tab on the left-hand menu. This is the recommended option, as it makes the image permanently available for you to run whenever you want.
    * **Run**: This action will download the image and immediately start the application. However, if you choose this option without pulling first, the PrEditR image will be deleted when your Docker session is terminated.
6.  Click the **Pull** button to download the selected image version.

### 3. Running the PrEditR App

Once the image is downloaded, you can launch the application from Docker Desktop under the “Images” tab or in the search bar (after the Pull step).

#### Understanding Images and Containers

Every time you run an image, Docker creates a new container. An **image** is the blueprint or template for the application, while a **container** is a live, running instance of that image. All of your active and past containers are listed in the `Containers` tab in Docker Desktop.

#### Step 1: Launch the Container

1.  In Docker Desktop, navigate to the `Images` tab on the left-hand menu.
2.  You will see the `fvasquezcastro/preditr` image you just pulled. Click the **Run** button (a blue triangle icon ▶️) next to the image name.

#### Step 2: Configure Optional Settings

A dialog box will appear. You must configure a few settings before starting the container.

1.  Click on **Optional settings**.
2.  **Ports**: In the `Host Port` field, assign a port number for the app to run on. A common choice is `3838`.
3.  **Volumes**: You need to connect a directory from your computer to the container to save your results.
    * In the `Host Path` field, click the `...` button and select a folder on your computer where you want the output files to be saved.
    * The `Container Path` must be set exactly to `/data`.
4.  **Environment variables** can be left empty.

> **Important for Off-Target Searches:** If you plan to perform off-target analysis, you must create a subfolder inside your chosen `Host Path` directory and place the indexed genome files there.

#### Step 3: Start the App

Click the blue **Run** button at the bottom of the configuration window. The PrEditR container will now start.

### 4. Accessing PrEditR

You're all set! Open your favorite web browser and navigate to:

`http://127.0.0.1:<port_number>`

Replace `<port_number>` with the port you specified in the settings (e.g., `http://127.0.0.1:3838`). You can now use the PrEditR Shiny app.

### 5. Managing PrEditR Containers

#### Running Multiple Instances

You can run multiple instances of PrEditR simultaneously in different containers. To do this, simply return to the `Images` tab, click the **Run** button on the PrEditR image again, and assign a different `Host Port` (e.g., `3839`, `3840`, etc.) for the new container. Each instance will be listed separately in the `Containers` tab.

#### Stopping and Cleaning Up

When you are done using PrEditR, closing the app in your web browser is not enough as the container will continue to run in the background. To properly shut down the application and free up system resources, you must:

1.  Go to the `Containers` tab in Docker Desktop.
2.  Find the container running your PrEditR instance. You can identify it by the image name and the port number.
3.  Click the **stop button** (a square icon ⏹️) to halt the application.
4.  To remove the stopped container, click the **delete button** (a red trash bin icon 🗑️). This will delete the instance of the container, but your pulled image will remain safe in the `Images` tab for future use.

### 6. Using the PrEditR Shiny App

This guide will walk you through the parameters and input files required to run an analysis in PrEditR.

#### Main Page: Setting Up Your Run

On the homepage of the app, you will find several parameters to configure for your analysis.

##### General Parameters

* **Organism**: Select the organism you are working with from the dropdown menu. Options are *Human* or *Mouse*.
* **Job Name**: Provide a unique name for your analysis job. This will be used to name the output files.
* **Threads**: Specify the number of processor threads to use for the analysis.
    > ⚠️ **Important for Windows Users**: If you are running PrEditR on a Windows laptop, it is highly recommended to set `Threads` to `1`. Windows has a known overhead that can cause significantly higher RAM consumption. If your run starts and then stops with an "unexpected error," it is most likely that the process was terminated due to insufficient RAM. The primary solution is to reduce the number of threads.
* **Operating System**: Choose the operating system you are using from the dropdown menu (*Linux/MacOS* or *Windows*).

##### Off-Target Search

This section controls the search for potential off-target sites.

* **Perform Off-Target Search**: Select `TRUE` from this dropdown menu to enable the search, or `FALSE` to disable it.
* **Mismatches**: This numerical input (default is `3`) tells the tool to search for off-target sites that have a certain number of differences from your guide's spacer sequence. For example, a value of `3` will search for off-targets with 0, 1, 2, and 3 mismatches.
* **Alignments**: This parameter (default is `10`) helps filter out guides that may be promiscuous. It will discard any designed guide that has a perfect, zero-mismatch alignment to the genome greater than or equal to the number specified. For example, a value of `10` will filter out guides that perfectly align to 10 other places in the genome besides the gene you want here.
* **Indexed Genome Directory**: This field is mandatory if you set the search to `TRUE`. You must provide the name of the subfolder (located within the directory you mounted to `/data`) that contains the indexed genome files (in `.ebwt` format).
    > For example, if you mounted `C:\Users\YourUser\PrEditR_IO` to `/data`, and your indexed genome is in `C:\Users\YourUser\PrEditR_IO\hg38_index`, you would enter `hg38_index` in this field.

> **Note**: The `Mismatches`, `Alignments`, and `Indexed Genome Directory` fields are always visible. However, they will be completely ignored by the application if `Perform Off-Target Search` is set to `FALSE`.

#### Defining Your Base Editors

You must provide a CSV file that defines the properties of the base editors you intend to use.

Click the **Download Editors File Template** button to get a pre-formatted CSV file. You can then open this file in any spreadsheet software (like Excel, Google Sheets, or as a plain text file) and fill it out.

Each row in this file defines one editor. Here are the columns you need to complete:

| Column Name       | Description                                                                                                                                              | Example |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| **name** | A unique name for your editor. This name will be used to link to your targets.                                                                           | `ABE8e`   |
| **pam_sequence** | The Protospacer Adjacent Motif (PAM) sequence for the editor. Use 'N' for any nucleotide.                                                                | `NGG`     |
| **spacer_length** | The length (in nucleotides) of the guide RNA's spacer sequence.                                                                                            | `20`      |
| **edit_type** | The specific base conversion the editor performs (adenine to guanine “a2g” or cytosine to thymine “c2t”).                                                  | `a2g`     |
| **edit_window_min** | The start of the editing window. This is the closest position to the PAM (excluding the PAM) where editing can occur. It must be a negative number.     | `-13`     |
| **edit_window_max** | The end of the editing window. This is the furthest position from the PAM where editing can occur. It must also be a negative number.                    | `-17`     |

After filling out the template, save it as a CSV file and upload it to PrEditR.

#### Defining Your Targets

Next, you need to provide a CSV file describing the specific genomic targets you want to edit.

Just like with the editors, you can click the **Download Targets File Template** button to get a correctly formatted file to fill in.

Each row in this file represents an independent editing task. Here is a description of the columns:

| Column Name       | Description                                                                                                                                                                                          |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **gene_symbol** | The official symbol for the target gene (e.g., `KRAS`). You can leave `ensembl_id` blank if you provide this.                                                                                            |
| **ensembl_id** | The Ensembl transcript ID (e.g., `ENST00000256078`). Using the transcript ID is highly encouraged for precision. If only a gene symbol is given, the tool will search all its transcripts and report results for the first one found containing the target amino acid at the specified position. |
| **target_aa** | The single-letter code for the amino acid you wish to edit (e.g., `W` for Tryptophan).                                                                                                                   |
| **target_position** | The numerical position of that amino acid within the protein sequence.                                                                                                                             |
| **editor** | The name of the editor you want to use for this specific target. This name must exactly match a name from your `editors.csv` file.                                                                    |
| **edit_type** | The type of edit (`a2g` or `c2t`). This should also match the edit type defined for the chosen editor in your `editors.csv` file.                                                                       |

You have great flexibility in this file:

* You can mix and match, providing Ensembl IDs for some rows and only gene symbols for others.
* You can use different editors for different targets in the same run, as long as each editor is correctly defined in your editors file.

Once your targets file is ready, save it as a CSV file and upload it using the **Upload targets CSV** button.

#### Running the Analysis

After all parameters are set and files are uploaded:

1.  Click the blue **Run Batch** button.
2.  An animated progress bar will appear, showing you that the analysis is underway. Please be patient as this may take some time depending on the size of your job.
3.  Upon completion, a pop-up window will appear:
    * A **success message** indicates that the run finished correctly and your output files are in the local directory you bound as a volume.
    * An **error message** indicates something went wrong. As noted earlier, this is most commonly caused by the process running out of memory (RAM). If you encounter this, please try reducing the number of `Threads` and run the analysis again.

---

## Command Line Version

*Documentation to be added here.*
