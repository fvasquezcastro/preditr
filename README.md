# PrEditR Documentation

This document provides instructions for running PrEditR, either through the Shiny interface or via the command line.

## Shiny App Version

This section details the setup and operation of the PrEditR Shiny app using the Docker Desktop graphical user interface (GUI).

### 1. System Architecture

The system's chip architecture must be identified to download the correct Docker image.

* **`amd64`** (also known as `x86-64`): This architecture is utilized by most desktop and laptop computers with Intel and AMD processors.
* **`arm64`** (also known as `AArch64`): This architecture is common in mobile devices and is now used in newer laptops, including Apple's M-series chips and some Windows devices with Snapdragon processors.

### 2. Getting Started with Docker

PrEditR is packaged in a Docker container for simplified execution on any system.

#### Step 1: Install Docker Desktop

If not already installed, download and install Docker Desktop from the official Docker website. It is available for Windows, Mac, and Linux. A system restart is required after installation.

#### Step 2: Download the PrEditR Image using Docker Desktop

A Docker Hub account is not required to download the public PrEditR image.

1.  Open the Docker Desktop application.
2.  In the search bar at the top of the window, enter `fvasquezcastro/preditr` and press Enter.
3.  From the search results, select the `fvasquezcastro/preditr` image.
4.  On the right side of the screen is a **Tag** dropdown menu. The correct tag for the system's architecture must be selected:
    * `v3_amd64` for Intel/AMD systems.
    * `v3_arm64` for Apple M-series/Snapdragon systems.
5.  Two options are presented: **Pull** and **Run**.
    * **Pull**: Downloads the image to the local machine, where it is stored in the `Images` tab. This action makes the image permanently available for later use.
    * **Run**: Downloads the image and immediately starts the application. If this option is chosen without first pulling, the image is deleted when the Docker session is terminated.
6.  Click the **Pull** button to download the selected image version.

### 3. Running the PrEditR App

Once the image is downloaded, the application can be launched from Docker Desktop under the `Images` tab or from the search bar.

#### Understanding Images and Containers

Each time an image is run, Docker creates a new container. An **image** is the application template, while a **container** is a live, running instance of that image. All active and past containers are listed in the `Containers` tab in Docker Desktop.

#### Step 1: Launch the Container

1.  In Docker Desktop, navigate to the `Images` tab on the left-hand menu.
2.  Locate the `fvasquezcastro/preditr` image that was pulled. Click the **Run** button next to the image name.

#### Step 2: Configure Optional Settings

A dialog box will appear where settings must be configured before starting the container.

1.  Click on **Optional settings**.
2.  **Ports**: In the `Host Port` field, assign a port number for the application (e.g., `3838`).
3.  **Volumes**: A local directory must be connected to the container to save results.
    * In the `Host Path` field, use the `...` button to select a folder on the local computer where output files will be saved.
    * The `Container Path` must be set to `/data`.
4.  **Environment variables** can be left empty.

> **Note on Off-Target Searches:** If off-target analysis will be performed, a subfolder containing the indexed genome files must be created inside the chosen `Host Path` directory.

#### Step 3: Start the App

Click the blue **Run** button at the bottom of the configuration window to start the PrEditR container.

### 4. Accessing PrEditR

Open a web browser and navigate to the following address:

`http://127.0.0.1:<port_number>`

Replace `<port_number>` with the port specified in the settings (e.g., `http://127.0.0.1:3838`). The PrEditR Shiny app is now accessible.

### 5. Managing PrEditR Containers

#### Running Multiple Instances

Multiple instances of PrEditR can run simultaneously in different containers. To do this, return to the `Images` tab, click the **Run** button on the PrEditR image again, and assign a different `Host Port` (e.g., `3839`, `3840`) for the new container. Each instance will be listed as a separate entry in the `Containers` tab.

#### Stopping and Cleaning Up

Closing the browser tab does not terminate the container, which continues to run in the background and consume system resources. To shut down the application:

1.  Navigate to the `Containers` tab in Docker Desktop.
2.  Find the container running the PrEditR instance, identified by the image name and port number.
3.  Click the **stop button** to halt the application.
4.  To remove the stopped container, click the **delete button**. This action deletes the container instance, but the pulled image is preserved in the `Images` tab for future use.

### 6. Using the PrEditR Shiny App

This section describes the parameters and input files required to run an analysis in PrEditR.

#### Main Page: Setting Up Your Run

The application's homepage contains several parameters to configure for an analysis.

##### General Parameters

* **Organism**: Select the organism (*Human* or *Mouse*) from the dropdown menu.
* **Job Name**: Provide a unique name for the analysis job, which will be used for naming the output files.
* **Threads**: Specify the number of processor threads to allocate for the analysis.
    > **Warning:** For users on Windows, it is recommended to set `Threads` to `1`. The operating system has a known overhead that can cause high RAM consumption, leading to unexpected errors. If a run terminates unexpectedly, the most likely cause is insufficient RAM, and the primary solution is to reduce the thread count.
* **Operating System**: Select the operating system (*Linux/MacOS* or *Windows*) from the dropdown menu.

##### Off-Target Search

This section controls the search for potential off-target sites.

* **Perform Off-Target Search**: Select `TRUE` to enable the search, or `FALSE` to disable it.
* **Mismatches**: A numerical input (default: `3`) that instructs the tool to search for off-target sites with up to this number of differences from the guide's spacer sequence. A value of `3` will find off-targets with 0, 1, 2, and 3 mismatches.
* **Alignments**: A parameter (default: `10`) that filters promiscuous guides. Any designed guide with a number of perfect, zero-mismatch alignments to the genome greater than or equal to this value will be discarded.
* **Indexed Genome Directory**: This field is mandatory if `Perform Off-Target Search` is `TRUE`. The value must be the name of the subfolder (located within the directory mounted to `/data`) that contains the indexed genome files (in `.ebwt` format).
    > For example, if the host path `C:\Users\YourUser\PrEditR_IO` is mounted to `/data`, and the indexed genome is located in `C:\Users\YourUser\PrEditR_IO\hg38_index`, the value for this field should be `hg38_index`.

> **Note**: The `Mismatches`, `Alignments`, and `Indexed Genome Directory` fields are ignored by the application if `Perform Off-Target Search` is set to `FALSE`.

#### Defining Your Base Editors

A CSV file defining the properties of the base editors is a required input.

Click the **Download Editors File Template** button to obtain a pre-formatted CSV file. This file can be populated using any spreadsheet software or a text editor.

Each row in this file defines one editor. The following columns must be completed:

| Column Name       | Description                                                                                                                                              | Example |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| **name** | A unique name for the editor, used to link to targets.                                                                                                   | `ABE8e
