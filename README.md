# PrEditR Documentation

## Table of Contents
- [About PrEditR](#about-preditr)
- [Understanding the Input](#understanding-the-input)
  - [Command-line arguments](#command-line-arguments)
  - [Defining Your Base Editors](#defining-your-base-editors)
  - [Defining Your Targets](#defining-your-targets)
- [Understanding the Output](#understanding-the-output)
- [Organism Reference Data](#organism-reference-data)
  - [Why references are external](#why-references-are-external)
  - [What a reference contains](#what-a-reference-contains)
  - [Two ways to supply a reference](#two-ways-to-supply-a-reference)
  - [Getting prebuilt reference images](#getting-prebuilt-reference-images)
  - [Building a custom reference (payload folder)](#building-a-custom-reference-payload-folder)
  - [How the app finds references](#how-the-app-finds-references)
- [Running the Shiny App (Docker Desktop)](#running-the-shiny-app-docker-desktop)
  - [1. Which version to download](#1-which-version-to-download)
  - [2. Option A: Docker Desktop GUI (recommended)](#2-option-a-docker-desktop-gui-recommended)
  - [3. Option B: Docker Compose](#3-option-b-docker-compose)
  - [4. Accessing and using PrEditR](#4-accessing-and-using-preditr)
  - [5. Managing PrEditR containers](#5-managing-preditr-containers)
- [Running in Command Line Mode](#running-in-command-line-mode)
  - [CLI via Docker Compose](#cli-via-docker-compose)
  - [CLI via `docker run` and a payload folder](#cli-via-docker-run-and-a-payload-folder)
  - [CLI via Singularity / Apptainer (HPC)](#cli-via-singularity--apptainer-hpc)
  - [Listing installed organisms](#listing-installed-organisms)
- [Example Walkthrough](#example-walkthrough)
  - [Example input files](#example-input-files)
  - [Expected results](#expected-results)
  - [CLI walkthrough (Singularity and a payload folder)](#cli-walkthrough-singularity-and-a-payload-folder)
  - [Shiny walkthrough (Docker Desktop)](#shiny-walkthrough-docker-desktop)
- [Limitations](#limitations)
- [Reporting Issues](#reporting-issues)

---

## About PrEditR

![main_fig](www/main_fig.png)

PrEditR designs CRISPR base editor sgRNAs from protein-level targets. Given a list of
proteins and amino acid positions, it enumerates candidate spacers for user-defined
base editors, annotates the amino acid change each guide would produce, and flags
guides for sequence composition, isoform conflicts, splice site proximity, and
off-targets.

PrEditR was developed by the [Myers Lab](https://www.samyerslab.org) at
[La Jolla Institute for Immunology](https://www.lji.org), originally to support
large-scale sgRNA design for post-translational modification (PTM) functional screens.

It runs as a Shiny web application and as a command-line batch tool. Both modes use the
same guide-design pipeline and the same organism reference model.

---

## Understanding the Input

### Command-line arguments

The Shiny app exposes the same options as form fields, so this table covers both modes.
Paths passed to the CLI are paths inside the container. Bind or mount them as shown in
[Running in Command Line Mode](#running-in-command-line-mode).

| Argument | Required? | Default | Description |
| :--- | :--- | :--- | :--- |
| `--input` | Yes | none | Path to the targets CSV (see [Defining Your Targets](#defining-your-targets)). |
| `--editors` | Yes | none | Path to the editors CSV (see [Defining Your Base Editors](#defining-your-base-editors)). |
| `--output` | Yes | none | Output directory. Must already exist. |
| `--tmp` | Yes | none | Scratch directory for the run. Must already exist. Its contents are cleared on exit. |
| `--organism` | Yes, unless `--reference` is given | none | Organism id of an installed reference, such as `human` or `mouse`. When `--reference` is given, the id is read from the payload manifest instead. |
| `--reference` | No | none | Path to a single organism's payload directory, meaning the folder that directly contains `preditr_reference.json`. One-shot alternative to `--references_path` plus `--organism`. The directory name must equal the organism id. This is a plain filesystem path, so it behaves identically under Docker and Singularity. |
| `--references_path` | No | `/refs` | Base directory holding per-organism references. Overrides the `PREDITR_REFERENCES_PATH` environment variable. |
| `--job_name` | No | `PrEditR_job` | Name used in output filenames. Letters, numbers, and `( ) . _` only. |
| `--threads` | No | `4` | Number of parallel workers. Budget roughly 1.5 GB RAM baseline plus 1.5 GB per additional thread. |
| `--off_targets` | No | `FALSE` | `TRUE` enables the off-target search. Requires `--indexed_genome`. |
| `--indexed_genome` | If `--off_targets TRUE` | none | Folder of Bowtie `.ebwt` index files for the organism's genome. |
| `--n_mismatches` | No | `3` | Maximum mismatches when searching for off-targets (max 10). |
| `--n_max_alignments` | No | `3` | Discard guides with more than this many exact, zero-mismatch genomic alignments. |
| `--non_editing_controls` | No | `FALSE` | `TRUE` also returns, per gene, guides whose edit window makes no edit. |
| `--dna_context` | No | `FALSE` | `TRUE` appends `dna_context_upstream`, `dna_edit_window`, and `dna_context_downstream` to the output. |
| `--flanking5` / `--flanking3` | No | `""` | 5' and 3' sequence appended to each spacer when screening for restriction sites. |
| `--list_organisms` | No | none | Print the organisms installed under the references path and exit. |

### Defining Your Base Editors

The editors CSV requires these six columns. Column names must match exactly.

| Column Name | Description | Example |
| :--- | :--- | :--- |
| `editor_name` | Unique name for the editor. Target rows reference this value. | `ABE8e-SpCas9` |
| `pam` | PAM sequence. Use `N` for any nucleotide. | `NGG` |
| `spacer_length` | Length in nucleotides of the guide RNA spacer. | `20` |
| `edit_type` | Base conversion the editor performs, for example `a2g` or `c2t`. | `a2g` |
| `edit_window_min` | Start of the editing window, the position closest to the PAM. Must be negative. | `-13` |
| `edit_window_max` | End of the editing window, the position furthest from the PAM. Must be negative. | `-17` |

Two further columns, `addgene_optional` and `reference_optional`, are optional. They
carry an Addgene URL and a publication DOI, which the Shiny app displays alongside the
editor. See `www/editors_example.csv`, which the Direct Input tab also uses as its
editor catalog.

### Defining Your Targets

All seven columns below must be present as headers, even when a column is left blank on
every row.

At least one of gene symbol, Ensembl transcript ID, or UniProt ID is required per
target. Any one is sufficient. When more than one is given, the Ensembl transcript ID
takes precedence over the UniProt ID, which takes precedence over the gene symbol. A
gene symbol on its own resolves to the gene's canonical transcript.

Gene-symbol and UniProt-ID input depend on the selected organism's reference including
the corresponding ID maps. All curated references include them. A custom FASTA/GFF
reference built without those maps accepts Ensembl transcript IDs only, as described in
[Building a custom reference](#building-a-custom-reference-payload-folder).

| Column Name | Description |
| :--- | :--- |
| `gene_symbol` | Official symbol for the target gene, for example `KRAS`. Sufficient on its own, and resolves to the canonical transcript. |
| `ensembl_id` | Ensembl transcript ID, for example `ENST00000256078`. Recommended for isoform precision. |
| `uniprot_id` | UniProt accession, for example `P01116`. Use an isoform-qualified accession such as `P38398-1` when a bare accession maps to several isoforms. |
| `target_aa` | Single-letter code for the target amino acid, for example `V`. |
| `target_position` | Position of the target amino acid in the protein sequence. |
| `editor` | Editor for this target. Must match an `editor_name` in the editors file. |
| `edit_type` | Edit type. Must match the `edit_type` defined for the chosen editor. |

See `www/targets_example.csv` for a reference file.

---

## Understanding the Output

A run writes `<job_name>_results.csv` and `<job_name>.log` to the output directory. The
Shiny app additionally writes `<job_name>_summary_plot.svg` and an interactive results
`.rds` used by the Explore Results tab.

The results CSV contains one row per candidate guide. A target that yields several
guides produces several rows. A target that yields none still produces one row, with
the literal text `No guides found` in `protospacer_seq` and the annotation columns left
empty. That is a normal outcome, not an error: it means no PAM placed an editable base
inside the editing window for that codon.

| Column Header | Explanation |
| :--- | :--- |
| `query_num` | Index of the target row in the input file. |
| Input columns | The seven target columns are carried through unchanged, with `uniprot_id` and `ensembl_id` filled in where they were resolved by ID mapping. |
| `gene_strand` | Strand the gene is located on, `+` or `-`. |
| `protospacer_seq` | DNA sequence the guide RNA is designed to bind, or `No guides found`. |
| `percent_gc` | Percentage of G and C bases in the protospacer. |
| `protospacer_strand` | Strand the protospacer is on, `+` or `-`. |
| `pam_seq` | PAM sequence. |
| `chromosome` | Chromosome of the target sequence. |
| `pam_coordinates_start` | Genomic start coordinate, lower position, of the PAM. |
| `pam_coordinates_end` | Genomic end coordinate, higher position, of the PAM. |
| `protospacer_coordinates_start` | Genomic start coordinate, lower position, of the protospacer. |
| `protospacer_coordinates_end` | Genomic end coordinate, higher position, of the protospacer. |
| `polyA`, `polyC`, `polyG`, `polyT` | `TRUE` if the protospacer contains a homopolymer run of at least 4 nt of the given base. A `polyT` run is a Pol III terminator that can truncate U6-driven sgRNA transcription. |
| `startingGGGGG` | `TRUE` if the protospacer begins with five G's. |
| `mutation_type` | Classification of the resulting mutation: `missense`, `nonsense`, or `silent`. |
| `wildtype_sequence` | Original amino acid sequence, plus or minus 7 residues. The target codon is delimited by vertical bars. |
| `mutant_sequence` | Resulting amino acid sequence after the edit, in the same format. |
| `edits` | Amino acid changes the guide produces, for example `S988P`. Comma separated when the editing window changes more than one residue. |
| `warnings` | Non-fatal notes about the design, such as `Multiple edits.` when the window alters more than one codon, or `Silent mutation for target aa.` when the target residue itself is unchanged. |
| `error` | Reason a row failed, for example an unresolvable identifier. Empty for rows that simply yielded no guide. |
| `EcoRI`, `KpnI`, `BsmBI`, `BsaI`, `BbsI`, `PacI`, `MluI` | One boolean column per enzyme, flagging recognition-site changes caused by the edit. Any `--flanking5` or `--flanking3` sequence is included in the screen. |
| `dna_context_upstream`, `dna_edit_window`, `dna_context_downstream` | Present only when `--dna_context TRUE`. Raw genomic DNA of the edit window and the 50 nt immediately upstream and downstream, in the sgRNA's own 5' to 3' orientation. |
| `blosum_score` | BLOSUM62 substitution score for each change listed in `edits`, comma separated in the same order. |
| `plddt_score` | AlphaFold pLDDT confidence for the target residue. Populated only when the organism's reference includes a `maps/plddt.rds` map. The curated references do not currently ship one, so this column is normally empty. |
| `alignments_n0` through `alignments_n3` | Off-target alignment counts by mismatch number. Present only when `--off_targets TRUE`. |

---

## Organism Reference Data

### Why references are external

The PrEditR application image contains only the guide-design software. It ships no
genome or annotation data. This keeps the image small and allows organisms to be added
without modifying the app.

PrEditR reads organism data at runtime from a references directory, `/refs` by default,
configurable with the `PREDITR_REFERENCES_PATH` environment variable or the
`--references_path` flag. Each organism occupies its own subdirectory, and the app
discovers what is installed by scanning for manifest files. Adding an organism requires
only making its reference available under the references directory.

### What a reference contains

One organism's reference is a self-contained directory:

```text
<references_path>/<organism_id>/
  preditr_reference.json     # discovery manifest (organism id, genome build, packages)
  rlib/                      # the organism's R packages, such as the BSgenome package
  annotation/
    txdb.rds                 # normalized annotation, a crisprDesignData-style GRangesList
  maps/                      # ID maps: uniprot to ensembl, symbol to ensembl, isoform flags
```

The `preditr_reference.json` manifest is the key file, and its presence is what marks a
directory as an installed organism. It records the `organism_id` passed to `--organism`
or selected in the dropdown, the human-readable `organism_label` shown in the dropdown,
the `genome_build`, and the Bioconductor version the reference was built for. The
reference's Bioconductor version must match the application image's. PrEditR checks this
at load time and fails with an explicit error rather than failing later in the pipeline.

### Two ways to supply a reference

Both produce the same per-organism files and are consumed identically by the app and the
CLI.

| | Reference image | Payload folder |
| :--- | :--- | :--- |
| What it is | A Docker image `fvasquezcastro/preditr-ref:<organism>-<genome>` wrapping the reference directory | The same reference directory as plain files on disk |
| How it reaches the app | A one-shot initializer container copies its payload into a shared `/refs` volume, then exits | You mount or point the app at the folder directly via `PREDITR_REFERENCES_PATH` |
| Best for | Distributing curated organisms to many users through `docker compose up` | A single machine or lab, HPC, or custom organisms you built yourself |
| How you obtain it | `docker pull` from Docker Hub | Build with the `ref-builder` image, or stage one out of a reference image |

The two can be mixed. A references directory can hold some organisms populated by
reference images and others dropped in as payload folders. The app discovers all of them
the same way.

### Getting prebuilt reference images

Curated reference images are published on Docker Hub under
[`fvasquezcastro/preditr-ref`](https://hub.docker.com/r/fvasquezcastro/preditr-ref). The
tag encodes the organism and genome build:

```text
fvasquezcastro/preditr-ref:human-grch38        # human, GRCh38
fvasquezcastro/preditr-ref:mouse-mm10          # mouse, mm10
fvasquezcastro/preditr-ref:yeast-saccer3       # yeast, sacCer3
fvasquezcastro/preditr-ref:rat-rn7             # rat, rn7
fvasquezcastro/preditr-ref:zebrafish-danrer11  # zebrafish, danRer11
fvasquezcastro/preditr-ref:fruitfly-dm6        # fruit fly, dm6
fvasquezcastro/preditr-ref:celegans-ce11       # C. elegans, ce11
fvasquezcastro/preditr-ref:chicken-galgal6     # chicken, galGal6
```

These eight organisms are enabled in the reference registry,
`run/reference_organisms.tsv`. Reference images are published as multi-arch manifests
covering amd64 and arm64, and their payloads are architecture-agnostic, containing the
genome data package and prebuilt `.rds` annotation but no compiled code. Docker pulls the
correct variant automatically and nothing runs under emulation.

With Docker Compose these are not usually pulled by hand. The Compose generator wires the
reference images it finds, and Docker pulls anything still missing on the first `up`. By
default the generator wires only organisms whose image is already present locally
according to `docker image ls`, so pull the ones you want first, or pass `--no-filter` to
wire every enabled organism.

### Building a custom reference (payload folder)

For an organism that is not published, or for a different genome build, a reference can
be built from a genome FASTA plus an annotation GFF3/GTF, with an optional UniProt to
transcript map to enable UniProt-ID input. The prebuilt reference-builder image contains
the full R and Bioconductor toolchain, so a build is a single `docker run` that outputs a
payload folder:

```sh
docker run --rm -u "$(id -u):$(id -g)" \
  -v /path/to/inputs:/in:ro \
  -v "$PWD/refs":/out \
  fvasquezcastro/preditr-ref:ref-builder \
  --organism newt --label "Newt" --genome-build newt1 \
  --genome-fasta   /in/newt.fa \
  --annotation-gff /in/newt.gff3 \
  --uniprot-map    /in/newt_uniprot.tsv     # optional
```

This writes `./refs/newt/`, a ready-to-use payload folder. Point the app at the base
directory containing it, `PREDITR_REFERENCES_PATH="$PWD/refs"`, and `newt` becomes an
installed organism. Using `-u "$(id -u):$(id -g)"` keeps output files host-owned. Mount
inputs read-only and the output directory read-write.

For all options, including `--annotation-format`, `--genome-organism`, `--provider`,
`--standard-chrom-only`, and `--out`:

```sh
docker run --rm fvasquezcastro/preditr-ref:ref-builder --help
```

Reference building lives in a separate `preditr_ref` project, which builds and publishes
the per-organism reference images and the `ref-builder` image, and documents the payload
contract, the UniProt map TSV format, the organism registry, and how to package a payload
folder into a distributable reference image. This repository only consumes references.
Prebuilt reference images for every supported organism are published on
[Docker Hub](https://hub.docker.com/r/fvasquezcastro/preditr-ref), so the build tooling is
not required to run PrEditR.

### How the app finds references

At startup for Shiny, and at job dispatch for the CLI, PrEditR scans the references
directory for `*/preditr_reference.json` and treats each match as an installed organism.

* The base directory is resolved in this order: the `--references_path` argument, then the
  `PREDITR_REFERENCES_PATH` environment variable, then `/refs`.
* Shiny: the Organism dropdowns on the Direct Input and Batch Search tabs are populated
  from the discovered manifests. The label shown is the manifest's `organism_label`, and
  selecting it passes the `organism_id` to the pipeline. If nothing is discovered, the app
  falls back to its static choices.
* CLI: pass the `organism_id` to `--organism`. Use `--list_organisms` to print what is
  installed.

---

## Running the Shiny App (Docker Desktop)

The Shiny app is the recommended interface for users who do not work from a terminal.
There are two ways to launch it: the Docker Desktop GUI, which requires no terminal, and
Docker Compose, which is a single command and wires up references automatically.

### 1. Which version to download

Use the plain version tag, `fvasquezcastro/preditr:1.10.0`. It is a multi-arch manifest,
so Docker selects the build matching the processor automatically on Intel/AMD, Apple
Silicon, and Windows on ARM.

Arch-suffixed tags remain published for explicit pinning:

* `1.10.0_amd64` for Intel or AMD processors, meaning most Windows PCs and older Macs.
* `1.10.0_arm64` for Apple M-series chips and Snapdragon.

On Windows on ARM, do not pin. Docker Desktop on Windows/ARM cannot reliably run
`linux/amd64` containers, as there is no Rosetta equivalent, so an `_amd64` tag may fail
outright. The plain `1.10.0` tag resolves to the native arm64 build.

### 2. Option A: Docker Desktop GUI (recommended)

This path requires no terminal. Two components are downloaded: the app,
`fvasquezcastro/preditr`, and at least one organism, `fvasquezcastro/preditr-ref`. The app
contains the software; the organism contains the genome data. Two folders on the host hold
the organism data and the results.

#### Step 1: Install Docker Desktop and create two folders

1. Install Docker Desktop from the
   [Docker website](https://www.docker.com/products/docker-desktop/) and open it.
2. Create a folder called `preditr` containing two empty folders, `refs` and `outputs`:
   * macOS and Linux: `~/preditr/refs` and `~/preditr/outputs`
   * Windows: `C:\preditr\refs` and `C:\preditr\outputs`

   The full path to each is needed in the steps below.

#### Step 2: Download the app and an organism

In the Docker Desktop search bar, search for and pull each of the following.

| Search for | Tag | What it is |
| :--- | :--- | :--- |
| `fvasquezcastro/preditr` | `1.10.0` | The PrEditR app |
| `fvasquezcastro/preditr-ref` | `human-grch38`, or another organism from [the list](#getting-prebuilt-reference-images) | The organism's genome data |

To pull, type the name, click the result, choose the tag from the Tag dropdown, and click
Pull. Repeat for every organism required.

<!-- SCREENSHOT: www/docs/gui_step2_pull_images.png - Docker Desktop search results for fvasquezcastro/preditr with the Tag dropdown open -->

#### Step 3: Load the organism data into the `refs` folder

The reference image is an initializer that copies its data into the `refs` folder and then
exits. Run it once per organism.

1. Open the Images tab and click Run on the `fvasquezcastro/preditr-ref` image.
2. Click Optional settings and fill in one Volume:

   | Field | Value |
   | :--- | :--- |
   | Host path | the `refs` folder, for example `~/preditr/refs` |
   | Container path | `/refs` |

3. Click Run. The container runs briefly and stops on its own, which is the expected
   behavior. The `refs` folder now contains the organism, for example a `human` subfolder.
   Repeat for each organism downloaded.

<!-- SCREENSHOT: www/docs/gui_step3_reference_volume.png - Run dialog for the reference image with the /refs volume mapping filled in -->

#### Step 4: Start the PrEditR app

1. Open the Images tab and click Run on the `fvasquezcastro/preditr` image.
2. Click Optional settings and fill in the following.

   Ports:

   | Field | Value |
   | :--- | :--- |
   | Host port | `3838` |

   Volumes, using the plus button to add the second row:

   | Host path | Container path |
   | :--- | :--- |
   | the `refs` folder, for example `~/preditr/refs` | `/refs` |
   | the `outputs` folder, for example `~/preditr/outputs` | `/outputs` |

   Environment variables, using the plus button to add the second row:

   | Variable | Value |
   | :--- | :--- |
   | `PREDITR_REFERENCES_PATH` | `/refs` |
   | `PREDITR_OUTPUTS_PATH` | `/outputs` |

3. Click Run.

<!-- SCREENSHOT: www/docs/gui_step4_app_run_dialog.png - Run dialog for the app image showing port 3838, both volumes, and both environment variables -->

#### Step 5: Open PrEditR

Open a browser at [http://127.0.0.1:3838](http://127.0.0.1:3838). The organisms loaded in
Step 3 appear in the Organism dropdown. Results are written to the `outputs` folder on the
host. See [Accessing and using PrEditR](#4-accessing-and-using-preditr).

### 3. Option B: Docker Compose

Compose starts the reference initializer containers, which populate a shared `/refs`
volume, and the Shiny app, in the correct order, with one command. This repository ships a
ready-to-use Compose file at `run/compose.yaml`.

1. Install Docker Desktop from the
   [Docker website](https://www.docker.com/products/docker-desktop/).
2. Start the stack from the repository root:

   ```sh
   docker compose -f run/compose.yaml up
   ```

   Or use the wrapper, which creates the local output directory first:

   ```sh
   run/run_preditr_compose.sh
   ```

   On the first run, Docker pulls the application image and the reference images wired into
   the Compose file, the reference containers copy their payloads into the shared
   `preditr_refs` volume and exit, and then the Shiny container starts.
3. Open [http://localhost:3838](http://localhost:3838).
4. Results written inside the container at `/outputs` appear on the host under
   `run/preditr_outputs/`.

The organisms that appear are the ones the Compose file installs. To change the set, edit
the organism registry and regenerate the file:

```sh
# reference_organisms.tsv lists organisms and image tags; enabled=true rows are considered.
# By default only enabled organisms whose image is already pulled locally are wired.
run/generate_reference_compose.sh              # regenerate run/compose.yaml
run/generate_reference_compose.sh --no-filter  # wire every enabled organism; up will pull them
```

To populate a references directory without Compose, for example on HPC, use the
runtime-agnostic staging helper, which works with Docker and with Singularity/Apptainer:

```sh
run/sync_references.sh --all                       # stage every enabled organism
run/sync_references.sh human mouse yeast           # just these
run/sync_references.sh --runtime singularity --refs-dir /scratch/$USER/refs --all
```

To add a custom payload folder built with the `ref-builder` image, mount its parent
directory into the Shiny container alongside the shared volume by adding a bind mount to
the `preditr-shiny` service in `run/compose.yaml`:

```yaml
  preditr-shiny:
    image: fvasquezcastro/preditr:1.10.0
    ports:
      - "3838:3838"
    volumes:
      - preditr_refs:/refs           # curated organisms from reference images
      - ./my_refs/newt:/refs/newt    # custom payload folder, discovered as "newt"
      - ./preditr_outputs:/outputs
    environment:
      PREDITR_REFERENCES_PATH: /refs
```

The custom organism then appears in the dropdown alongside the curated ones.

### 4. Accessing and using PrEditR

Open a browser at [http://127.0.0.1:3838](http://127.0.0.1:3838).

* Organism: the dropdown on both the Direct Input and Batch Search tabs lists exactly the
  organisms discovered under the references directory. An organism that is missing has no
  installed reference. Confirm it was loaded into the `refs` folder (Option A Step 3) or
  wired into the Compose file.
* Direct Input tab: enter targets and select editors inline, with no CSV required.
* Batch Search tab: upload a targets CSV and an editors CSV, then click Run Batch.
* Explore Results and Download tabs: filter interactively, and download the results and the
  log.
* Errors: check the status pop-up. A common cause is insufficient RAM, which is addressed
  by reducing Threads.

### 5. Managing PrEditR containers

* Compose: stop the stack with `Ctrl-C`, then run `docker compose -f run/compose.yaml down`
  to remove the containers. The `preditr_refs` volume persists between runs, so references
  are not re-copied every time. Add `-v` to also remove the references volume.
* GUI: stop and delete the container in the Containers tab when finished to free system
  resources.

---

## Running in Command Line Mode

The same application image serves both the Shiny app and the CLI. Running the image with
no arguments launches Shiny; running it with arguments runs the CLI. As with the Shiny
app, the CLI needs a references directory, supplied the same two ways.

See [Command-line arguments](#command-line-arguments) for every flag, or print them from
the image:

```sh
docker run --rm fvasquezcastro/preditr:1.10.0 --help
```

### CLI via Docker Compose

The Compose stack includes a `preditr-cli` service behind the `cli` profile, which reuses
the same reference volume as the Shiny app. The reference initializer containers run first
via `depends_on`, so installed organisms are synced into `/refs` before the job starts.

```sh
# Input CSVs go in run/preditr_inputs/, mounted at /inputs; results land in run/preditr_outputs/
run/run_preditr_cli.sh \
  --input   /inputs/targets.csv \
  --editors /inputs/editors.csv \
  --output  /outputs \
  --organism human \
  --tmp     /outputs/tmp
```

Without the wrapper:

```sh
docker compose -f run/compose.yaml --profile cli run --rm preditr-cli \
  --input /inputs/targets.csv --editors /inputs/editors.csv \
  --output /outputs --organism human --tmp /outputs/tmp
```

`PREDITR_REFERENCES_PATH=/refs` is already set on the service, so `--organism` only has to
match an installed organism id.

### CLI via `docker run` and a payload folder

For a one-off run without Compose, mount a payload folder, meaning a references directory
containing organism subdirectories, directly at `/refs`. This is the natural fit for
references built with the `ref-builder` image.

```sh
docker run --rm \
  -v "$PWD/refs":/refs:ro \
  -v "$PWD/inputs":/inputs:ro \
  -v "$PWD/outputs":/outputs \
  fvasquezcastro/preditr:1.10.0 \
    --input    /inputs/targets.csv \
    --editors  /inputs/editors.csv \
    --output   /outputs \
    --organism newt \
    --references_path /refs \
    --tmp      /outputs/tmp \
    --threads  4
```

Reference images are initializer containers that copy their payload into a shared volume,
and that hand-off is what Compose orchestrates. For a plain `docker run` of the app, use a
payload folder mounted at `/refs` rather than a reference image. To convert a reference
image into a payload folder, use `run/sync_references.sh`.

### CLI via Singularity / Apptainer (HPC)

On HPC systems without Docker, run the same image under Singularity or Apptainer. Convert
the image to a `.sif` first, and bind a references directory so the container can discover
organisms. A payload folder on the shared filesystem is the simplest choice.

To build that references directory directly from the published images, with no Docker
daemon required, use `run/sync_references.sh`, which stages payloads via
`singularity exec docker://`:

```bash
run/sync_references.sh --runtime singularity --refs-dir $REFERENCES_PATH --all
```

Then run the job, replacing the placeholder paths:

```bash
IMAGE_PATH=/path/to/images/preditr_image.sif
INPUT_PATH=/path/to/input/targets_input.csv
EDITOR_PATH=/path/to/input/editors.csv
REFERENCES_PATH=/path/to/preditr_refs          # dir with per-organism subdirectories
INDEXED_GENOME_PATH=/path/to/genome/hg38_genome_index
OUTPUT_PATH=/path/to/output_directory
TEMPORARY_PATH=/path/to/temp_scratch
ORGANISM=human

singularity exec \
  --no-home \
  --env PREDITR_MODE=CLI \
  --env PREDITR_REFERENCES_PATH=$REFERENCES_PATH \
  --pwd /app \
  --bind $INPUT_PATH:$INPUT_PATH,$EDITOR_PATH:$EDITOR_PATH,$REFERENCES_PATH:$REFERENCES_PATH,$INDEXED_GENOME_PATH:$INDEXED_GENOME_PATH,$OUTPUT_PATH:$OUTPUT_PATH,$TEMPORARY_PATH:$TEMPORARY_PATH \
  $IMAGE_PATH /app/PrEditR.R \
    --job_name your_analysis_job \
    --input $INPUT_PATH \
    --output $OUTPUT_PATH \
    --editors $EDITOR_PATH \
    --organism $ORGANISM \
    --references_path $REFERENCES_PATH \
    --off_targets FALSE \
    --indexed_genome $INDEXED_GENOME_PATH \
    --threads 30 \
    --tmp $TEMPORARY_PATH \
    --non_editing_controls FALSE \
    --dna_context FALSE
```

`PREDITR_MODE=CLI` forces command-line mode. `--references_path`, mirrored by the
`PREDITR_REFERENCES_PATH` environment variable, points PrEditR at the bound references
directory.

Every directory passed to the CLI must be bound into the container, including the `--tmp`
scratch directory. An unbound `--tmp` path fails during argument checking, because the
container cannot create or write it.

### Listing installed organisms

Before running a job, confirm which organisms are discoverable:

```sh
# Docker
docker run --rm -v "$PWD/refs":/refs:ro fvasquezcastro/preditr:1.10.0 \
  --list_organisms --references_path /refs

# Docker Compose, using the shared /refs volume
docker compose -f run/compose.yaml --profile cli run --rm preditr-cli --list_organisms
```

The output lists each `organism_id`, its genome build, and the Bioconductor version it was
built for. If nothing is listed, no reference is installed.

---

## Example Walkthrough

This section designs guides for a small set of human BRCA1 targets using two editors: the
adenine base editor ABE8e-SpCas9 (A to G) and the cytosine base editor BE3 (C to T). The
same two input files drive both the CLI and the Shiny walkthroughs.

### Example input files

`editors.csv` defines the two editors. Both use an NGG PAM, a 20 nt spacer, and an editing
window spanning positions -13 to -17 relative to the PAM.

```text
editor_name,pam,spacer_length,edit_type,edit_window_min,edit_window_max
ABE8e-SpCas9,NGG,20,a2g,-13,-17
BE3,NGG,20,c2t,-13,-17
```

`targets.csv` lists six BRCA1 residues, three assigned to the CBE and three to the ABE. All
targets are anchored to the canonical BRCA1 transcript `ENST00000357654`. The `uniprot_id`
column is present but empty, which is required: all seven columns must exist as headers
even when unused.

```text
gene_symbol,ensembl_id,uniprot_id,target_aa,target_position,editor,edit_type
BRCA1,ENST00000357654,,T,161,BE3,c2t
BRCA1,ENST00000357654,,R,213,BE3,c2t
BRCA1,ENST00000357654,,S,217,BE3,c2t
BRCA1,ENST00000357654,,S,988,ABE8e-SpCas9,a2g
BRCA1,ENST00000357654,,S,1423,ABE8e-SpCas9,a2g
BRCA1,ENST00000357654,,S,1431,ABE8e-SpCas9,a2g
```

The three ABE targets are serines in the BRCA1 regions targeted by checkpoint kinases:
S988 is a CHK2 site, and S1423 and S1431 lie in the ATM-phosphorylated cluster of the
C-terminal region.

### Expected results

Running the files above with `--off_targets FALSE --dna_context TRUE` produces seven rows
for six targets.

| Target | Editor | Guides | `edits` | `mutation_type` | Protospacer | PAM | Strand | GC |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| T161 | BE3 | 1 | `T161I` | missense | `TTGGAACTGTGAGAACTCTG` | AGG | - | 45 |
| R213 | BE3 | 2 | `D214N, E215K` | missense | `TTTCATCCCTGGTTCCTTGA` | GGG | + | 45 |
| R213 | BE3 | | `R213K, D214N` | missense | `TTCATCCCTGGTTCCTTGAG` | GGG | + | 50 |
| S217 | BE3 | 1 | `S217N` | missense | `ATCCAAACTGATTTCATCCC` | TGG | + | 40 |
| S988 | ABE8e-SpCas9 | 1 | `S988P` | missense | `AATGACTTGATGGGAAAAAG` | TGG | + | 35 |
| S1423 | ABE8e-SpCas9 | 0 | | | `No guides found` | | | |
| S1431 | ABE8e-SpCas9 | 1 | `S1431P` | missense | `ATGGAAGGGTAGCTGTTAGA` | AGG | + | 45 |

Three points this example illustrates:

* **A target can yield more than one guide.** R213 returns two, editing different
  combinations of neighbouring codons. Both carry the `Multiple edits.` warning because
  the editing window alters more than one residue.
* **A target can yield no guide.** S1423 returns `No guides found` with an empty `error`
  column. No NGG PAM places an editable adenine inside the ABE8e window for that codon.
  This is a normal result. Across all 335 serine and threonine positions in BRCA1, roughly
  a quarter yield an ABE8e-SpCas9 guide.
* **The reported edit follows the guide's strand.** Both ABE hits convert serine to
  proline: the guides lie on the coding strand, so the A-to-G edit reads as T-to-C on the
  transcript, changing `TCx` to `CCx`.

### CLI walkthrough (Singularity and a payload folder)

This walkthrough uses Apptainer or Singularity with a human payload folder staged on a
shared filesystem, which is the standard HPC configuration. Substitute `singularity` for
`apptainer` if that is what the system provides.

#### Step 1: Build the image

```bash
apptainer build preditr_1.10.0.sif docker://fvasquezcastro/preditr:1.10.0
```

The plain tag is a multi-arch manifest, so the correct architecture is selected
automatically.

#### Step 2: Create the working directories

```bash
export WORK=/scratch/$USER/preditr_demo
mkdir -p $WORK/inputs $WORK/outputs $WORK/tmp $WORK/refs
```

`--output` and `--tmp` must already exist. PrEditR does not create them.

#### Step 3: Stage the human reference

`run/sync_references.sh` lives in this repository and stages payloads out of the published
images without a Docker daemon:

```bash
git clone https://github.com/fvasquezcastro/preditr.git
cd preditr
run/sync_references.sh --runtime singularity --refs-dir $WORK/refs human
```

This writes `$WORK/refs/human/`, containing `preditr_reference.json`, `annotation/`,
`maps/`, and `rlib/`, and occupying roughly 1.1 GB.

#### Step 4: Write the input files

```bash
cat > $WORK/inputs/editors.csv <<'CSV'
editor_name,pam,spacer_length,edit_type,edit_window_min,edit_window_max
ABE8e-SpCas9,NGG,20,a2g,-13,-17
BE3,NGG,20,c2t,-13,-17
CSV

cat > $WORK/inputs/targets.csv <<'CSV'
gene_symbol,ensembl_id,uniprot_id,target_aa,target_position,editor,edit_type
BRCA1,ENST00000357654,,T,161,BE3,c2t
BRCA1,ENST00000357654,,R,213,BE3,c2t
BRCA1,ENST00000357654,,S,217,BE3,c2t
BRCA1,ENST00000357654,,S,988,ABE8e-SpCas9,a2g
BRCA1,ENST00000357654,,S,1423,ABE8e-SpCas9,a2g
BRCA1,ENST00000357654,,S,1431,ABE8e-SpCas9,a2g
CSV
```

#### Step 5: Confirm the reference is discoverable

```bash
apptainer exec \
  --no-home \
  --env PREDITR_MODE=CLI \
  --pwd /app \
  --bind $WORK:$WORK \
  preditr_1.10.0.sif /app/PrEditR.R \
    --list_organisms \
    --references_path $WORK/refs
```

The output lists `human`, its genome build GRCh38, and the Bioconductor version the
reference was built for:

```text
Available organisms:
  human        GRCh38 (Bioconductor 3.19)
```

If nothing is listed, Step 3 did not complete.

#### Step 6: Run the job

Binding `$WORK` in one mount covers `inputs`, `outputs`, `tmp`, and `refs` together.

```bash
apptainer exec \
  --no-home \
  --env PREDITR_MODE=CLI \
  --pwd /app \
  --bind $WORK:$WORK \
  preditr_1.10.0.sif /app/PrEditR.R \
    --job_name brca1_demo \
    --input    $WORK/inputs/targets.csv \
    --editors  $WORK/inputs/editors.csv \
    --output   $WORK/outputs \
    --tmp      $WORK/tmp \
    --organism human \
    --references_path $WORK/refs \
    --threads  4 \
    --off_targets FALSE \
    --dna_context TRUE
```

Off-target searching is disabled here because it requires a Bowtie index supplied via
`--indexed_genome`. To enable it, add `--off_targets TRUE --indexed_genome <dir>` and bind
that directory as well.

Memory scales with `--threads`: roughly 1.5 GB baseline plus 1.5 GB per additional thread.
Size the job's memory request accordingly.

#### Step 7: Inspect the output

```bash
ls $WORK/outputs
# brca1_demo_results.csv
# brca1_demo.log
```

`brca1_demo_results.csv` holds the rows shown in [Expected results](#expected-results),
carrying the input columns plus the protospacer, PAM, genomic coordinates, GC content,
homopolymer flags, the amino acid change in `edits`, `mutation_type`, BLOSUM62 score,
restriction site flags, and the DNA context columns requested by `--dna_context TRUE`. For
the first row the sequence context reads:

```text
wildtype_sequence   VQLSNL|GT|VRTLRTK
mutant_sequence     VQLSNL|GI|VRTLRTK
dna_edit_window     GAACT
```

`brca1_demo.log` records the run, including per-row warnings such as ID mapping
ambiguities.

### Shiny walkthrough (Docker Desktop)

This walkthrough submits the same two files through the Shiny app, launched with the Docker
Desktop GUI.

#### Step 1: Start the app

Complete [Option A: Docker Desktop GUI](#2-option-a-docker-desktop-gui-recommended),
pulling `fvasquezcastro/preditr-ref:human-grch38` in Step 2 so that human is available.
After Step 5, the app is running at [http://127.0.0.1:3838](http://127.0.0.1:3838).

#### Step 2: Save the input files

Save the `editors.csv` and `targets.csv` from
[Example input files](#example-input-files) somewhere reachable from the file browser, for
example the `preditr` folder created in Option A Step 1. The `refs` and `outputs` folders
are used by the container; the input files can be stored anywhere on the host.

#### Step 3: Open the Batch Search tab

Confirm that the Organism dropdown lists Human. If it does not, the human reference was not
loaded into the `refs` folder in Option A Step 3.

<!-- SCREENSHOT: www/docs/shiny_step3_batch_tab.png - Batch Search tab with the Organism dropdown open showing Human -->

#### Step 4: Upload the two files and set the run options

1. Upload `targets.csv` in the targets field and `editors.csv` in the editors field.
2. Set Organism to Human.
3. Enter a job name, for example `brca1_demo`.
4. Set Threads according to available memory, using roughly 1.5 GB baseline plus 1.5 GB per
   additional thread.
5. Leave off-target searching disabled unless an indexed genome is mounted.
6. Enable the DNA context option to include the sequence context columns.

<!-- SCREENSHOT: www/docs/shiny_step4_batch_form.png - Batch Search form with both CSVs uploaded, organism set to Human, job name and threads filled in -->

#### Step 5: Run the batch

Click Run Batch. A status pop-up reports progress through ID mapping, guide design, and
result assembly. An error at this stage is most often insufficient memory, which is
addressed by lowering Threads and rerunning.

<!-- SCREENSHOT: www/docs/shiny_step5_progress.png - Status pop-up during a run -->

#### Step 6: Review the results

Open the Explore Results tab. The table holds the seven rows listed in
[Expected results](#expected-results) and can be filtered interactively, for example to
keep only missense edits, to exclude guides carrying a `polyT` run, or to compare the two
R213 guides against each other.

<!-- SCREENSHOT: www/docs/shiny_step6_explore_results.png - Explore Results tab showing BRCA1 guides for both editors with filters applied -->

#### Step 7: Download

Open the Download tab to retrieve the results CSV, the log, and the summary plot. These
files are also written to the `outputs` folder mapped in Option A Step 4.

<!-- SCREENSHOT: www/docs/shiny_step7_download.png - Download tab -->

---

## Limitations

1. Single transition: PrEditR assumes each base editor performs a single type of nucleotide
   conversion, for example A to G, C to T, or C to G. Editors capable of several conversion
   types must be defined as separate editor entries, one per conversion.
2. DNA only: only DNA base editors are supported. RNA base editors are not.
3. PAM orientation: PAM sequences are assumed to lie immediately 3' of the protospacer.
4. Uniform length: all protospacers designed in a single run must be the same length.
   Mixed-length designs cannot be combined in one execution.
5. Efficiency: PrEditR assumes uniform editing efficiency across all positions within the
   editing window. Position-specific weighted editing windows are not supported.
6. Organism references: the application image ships no genome or annotation data. At least
   one reference, image or payload folder, must be installed before running. Curated
   references are built from Ensembl-derived ID maps, with the exact provenance recorded in
   each reference's manifest. Custom references built from FASTA and GFF are only as
   complete as the inputs provided.
7. Bioconductor compatibility: a reference must be built for the same Bioconductor version
   as the application image. PrEditR checks this at load time and refuses to run on a
   mismatch. Rebuild the reference, or use a matching application image.
8. UniProt-ID mapping: UniProt to transcript mapping relies on the ID maps bundled with a
   reference. A custom reference built without a UniProt map accepts Ensembl transcript IDs
   only. For associations newer than a reference's ID-map snapshot, provide the Ensembl
   transcript ID directly to bypass mapping.
9. Structural confidence scores: `plddt_score` is populated only when a reference includes
   an AlphaFold pLDDT map at `maps/plddt.rds`. The curated references do not currently ship
   one, so the column is normally empty.

---

## Reporting Issues

Report problems using the Issues tab on this repository. The `error` and `warnings` columns
in the output files are the starting point for troubleshooting. Issues specific to building
or publishing organism reference images and payloads are tracked in the separate
`preditr_ref` project. The prebuilt images are on
[Docker Hub](https://hub.docker.com/r/fvasquezcastro/preditr-ref).
