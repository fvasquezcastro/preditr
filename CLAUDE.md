# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

**PrEditR** is a CRISPR base editor guide RNA (sgRNA) design tool developed at the Myers Lab (La Jolla Institute for Immunology). It accepts a list of protein targets (by UniProt or Ensembl ID) and amino acid positions, then designs sgRNAs for custom base editors that can make the desired mutations. It runs as both a **CLI batch tool** and a **Shiny web application**.

Current version: 1.7.0 (stable). Organism support: human (hg38) and mouse (mm10).

## Running the Application

**Shiny app (local development):**
```bash
R -e "shiny::runApp('.', host='0.0.0.0', port=3838)"
```

**CLI:**
```bash
Rscript PrEditR.R --help
Rscript PrEditR.R --input targets.csv --output results/ --organism human \
  --job_name my_job --editors editors.csv --threads 4
```

**Docker (end users):**
```bash
./build_base_image.sh   # Build base OS image (Bioconductor 3.19 + system libs)
./build_preditr.sh      # Build final PrEditR image (exposes port 3838)
```

**Install R dependencies:**
```bash
Rscript installResources.R
```

There is no automated test suite. Functional testing uses `www/editors_example.csv` and `www/targets_example.csv` as reference inputs; `www/example_output.csv` and `www/example_interactive_results.rds` are the expected outputs.

## Architecture

### Entry Points

- **`PrEditR.R`** — Top-level orchestrator. Detects CLI vs. Shiny mode, loads all functions, maps IDs, then parallelizes the per-target pipeline using `furrr::future_map`. Also contains the Shiny `runApp()` call.
- **`ui.R`** — Shiny UI: three tabs (Search/Configure, Explore Results, Download).
- **`server.R`** — Shiny server: handles file uploads, job dispatch, result display, and interactive filtering.
- **`global.R`** — Loaded before both `ui.R` and `server.R`; sets hosted-mode flags from `PREDITR_HOSTED` env var and configures Shiny limits.

### Per-Target Guide Design Pipeline

Each row of the input CSV goes through this sequence in `functions/process_row.R`:

1. **ID mapping** (`mapUniprot2Ensembl.R`, `mapEnsembl2Uniprot.R`, `mapEnsembl2MGI.R`) — resolves protein/transcript IDs using pre-built `.rds` maps in `maps/human/` and `maps/mouse/`.
2. **Codon location** (`findCodonLocus.R`) — finds the genomic coordinates of the target amino acid.
3. **Region of interest** (`findRegionsOfInterest.R`) — defines the editing window around the codon.
4. **Guide finding** (`findGuides.R`) — enumerates candidate spacers with valid PAM positions within the window using `crisprDesign`/`crisprBase`.
5. **Edit annotation** (`annotateEdits.R`) — determines what amino acid change each guide would produce.
6. **Non-editing control detection** (`isNEC.R`, `addNEC.R`) — identifies guides that cannot make the desired edit.
7. **Quality flagging** (`flagGuides.R`) — marks guides for GC content, homopolymers, restriction sites, isoform conflicts, splice site proximity, and off-targets.
8. **Off-target search** (`findOffTargets.R`) — optional; requires an indexed genome (BWA).
9. **Output formatting** (`generatePartialOutput.R`, `generateOutput.R`, `generatePrettyTable.R`).

### Parallelization

Uses `future` + `furrr`. Each row is an independent unit of work dispatched to a worker. Memory budget: ~1.5 GB baseline + ~1.5 GB per additional thread. The `future.globals.maxSize` option is set to 1 GB to allow large genomic objects to be passed to workers.

### Reference Data (`maps/`)

Pre-built `.rds` files (Ensembl Nov 2025) for both organisms:
- `uniprot_to_ensembl.rds` / `ensembl_to_uniprot.rds` — bidirectional protein↔transcript maps
- `ensembl_to_mgi.rds` (mouse only) — MGI gene symbol mappings
- `duplicated_uniprot.rds`, `has_isoforms.rds` — flags for ambiguous targets
- `ensembl_in_txdb.txt` — which Ensembl IDs have transcript-level annotation

These are loaded once at startup, not per-worker.

### Hosted vs. Local Modes

Controlled by the `PREDITR_HOSTED` environment variable (set in `global.R`). Hosted mode disables off-target searching by default, limits thread count, and restricts upload sizes. All feature flags flow from `global.R` into both `server.R` and `PrEditR.R`.

### Function Loading

`functions/loadFunctions.R` sources every `.R` file in `functions/` (except itself). `functions/loadLibraries.R` loads all required packages and suppresses messages. Both are sourced near the top of `PrEditR.R`.

## Key Input/Output Formats

**Target CSV columns:** `uniprot_id` (or `ensembl_id`), `target_aa`, `position`, `editor_name`

**Editor CSV columns:** `editor_name`, `pam`, `spacer_length`, `edit_type`, `edit_window_start`, `edit_window_end`

**Output CSV** includes: protospacer sequence, GC%, strand, PAM coordinates, genomic locus, mutation type (silent/missense/nonsense), off-target alignment count, restriction enzyme gain/loss, isoform flags.
