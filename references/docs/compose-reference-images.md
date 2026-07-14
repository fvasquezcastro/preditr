# Docker Compose reference image strategy

## Goal

Provide a simple Docker Desktop experience for non-computational users while making organism support easier to expand.

The target user workflow is:

```sh
docker compose up
```

Then the user opens:

```text
http://localhost:3838
```

The Shiny app should show available organisms in a dropdown and run PrEditR with the selected reference. Users should not have to understand R package installation, Bioconductor versions, or Docker volumes.

This branch includes a generated Compose file:

```text
run/compose.yaml
```

It also includes a helper wrapper:

```sh
run/run_preditr_compose.sh
```

The wrapper creates the local output directory and runs Compose with the root file.

## Chosen first implementation

Use Docker Compose with:

- one Shiny application image
- one reference image per organism
- one shared Docker volume mounted into the Shiny container

Reference images are one-shot initializer containers. They copy their prebuilt Bioconductor reference packages and metadata into the shared volume, then exit. The Shiny container reads the copied reference directories as local files.

This avoids a runtime reference API service and keeps PrEditR's execution model close to the current code: R loads genome and annotation resources locally.

## Runtime topology

```text
Docker Desktop
  |
  +-- refs-human container (preditr-ref:human-grch38)
  |     copies /image-refs/human -> shared volume /refs/human
  |     exits
  |
  +-- refs-mouse container (preditr-ref:mouse-mm10)
  |     copies /image-refs/mouse -> shared volume /refs/mouse
  |     exits
  |
  +-- preditr-shiny container
        reads /refs/*/preditr_reference.json
        loads selected organism reference
        writes user-visible outputs to /outputs
```

The Shiny image should not depend on the reference images being alive. It should only depend on files under `/refs`.

## Why not container-to-container reference calls

A separate running reference service is feasible, but it adds failure modes that are not useful for this first version:

- service startup ordering
- HTTP or socket API design
- slower sequence access than local indexed files
- more logs and debugging paths for users
- more code to maintain

For PrEditR, local package and file access is the simpler contract.

## Reference image contract

Each organism image must contain one reference directory under:

```text
/image-refs/<organism_id>/
```

The directory should include:

```text
/image-refs/<organism_id>/
  preditr_reference.json
  installed_packages.tsv
  annotation/
    txdb.rds
  rlib/
```

`rlib/` contains the installed R packages for that organism, for example a BSgenome package and any TxDb, EnsDb, OrgDb, or PrEditR-specific annotation package required by the adapter.

`annotation/txdb.rds` is the normalized PrEditR annotation object when `annotation_loader` is `rds`. It should be a crisprDesignData-style `GRangesList`, not a raw `TxDb` object.

`preditr_reference.json` is the stable discovery file used by the Shiny app.

The build also copies the repo's `maps/<organism_id>/` directory into the reference directory as `maps/`, so ID maps and the AlphaFold `plddt.rds` travel with the organism reference. `plddt.rds` is large and organism-specific, so it is excluded from the app image (`.dockerignore`) and lives only here; the app reads it at runtime from `<PREDITR_REFERENCES_PATH>/<organism>/maps/plddt.rds` (see `functions/lookupPLDDT.R`), falling back to the repo's `maps/<organism>/plddt.rds` for host CLI / local development. BLOSUM62 is organism-independent and comes from the `pwalign` package in the app image (the substitution matrices moved there from Biostrings in Bioconductor 3.19), so it is not shipped per organism.

Example:

```json
{
  "schema_version": "0.1",
  "organism_id": "human",
  "organism_label": "Human",
  "genome_build": "GRCh38",
  "bioconductor_version": "3.19",
  "r_library_path": "rlib",
  "packages": [
    "BSgenome.Hsapiens.UCSC.hg38",
    "crisprDesignData"
  ],
  "genome_package": "BSgenome.Hsapiens.UCSC.hg38",
  "annotation_package": "TxDb.Hsapiens.UCSC.hg38.knownGene",
  "annotation_object": "TxDb.Hsapiens.UCSC.hg38.knownGene",
  "annotation_loader": "rds",
  "annotation_source_loader": "package-object",
  "annotation_transform": "txdb2grangeslist",
  "annotation_path": "annotation/txdb.rds"
}
```

The app can discover available references by reading:

```text
/refs/*/preditr_reference.json
```

## Version compatibility

The Shiny image and reference images must use compatible R and Bioconductor versions.

For the current project, the base image is:

```text
bioconductor/bioconductor_docker:3.19
```

Reference images should use the same Bioconductor version unless the Shiny image is also upgraded. Installed packages copied from one image into another are not a good cross-version boundary.

Recommended image tags:

```text
fvasquezcastro/preditr:1.8.0_amd64
fvasquezcastro/preditr-ref:human-grch38
fvasquezcastro/preditr-ref:mouse-mm10
```

Avoid relying on `latest` for releases. The Compose file should pin a tested set of tags.

## Compose pattern

Generated `compose.yaml`:

```yaml
services:
  refs-human:
    image: fvasquezcastro/preditr-ref:human-grch38
    volumes:
      - preditr_refs:/refs
    command: ["sh", "-c", "rm -rf /refs/human && cp -a /image-refs/human /refs/human"]
    restart: "no"

  refs-mouse:
    image: fvasquezcastro/preditr-ref:mouse-mm10
    volumes:
      - preditr_refs:/refs
    command: ["sh", "-c", "rm -rf /refs/mouse && cp -a /image-refs/mouse /refs/mouse"]
    restart: "no"

  preditr-shiny:
    image: fvasquezcastro/preditr:1.8.0_amd64
    ports:
      - "3838:3838"
    volumes:
      - preditr_refs:/refs
      - ./preditr_outputs:/outputs
    environment:
      PREDITR_REFERENCES_PATH: /refs
      PREDITR_OUTPUTS_PATH: /outputs
    depends_on:
      refs-human:
        condition: service_completed_successfully
      refs-mouse:
        condition: service_completed_successfully

volumes:
  preditr_refs:
```

This keeps the user's mental model simple: start Compose, select organism, run analysis, download or retrieve outputs.

## Included files

```text
run/compose.yaml
run/docker-compose.references.yml
run/generate_reference_compose.sh
run/run_preditr_compose.sh
references/reference_organisms.tsv
references/build_reference_image.sh
references/build_all_reference_images.sh
references/docs/compose-reference-images.md
```

`run/compose.yaml` is the Docker Desktop Compose entry point.

`run/docker-compose.references.yml` is a copy generated for experimentation.

`references/reference_organisms.tsv` is the organism registry. Adding organisms should usually start there.

`references/build_reference_image.sh` builds one organism reference image.

`references/build_all_reference_images.sh` builds every enabled organism in the TSV.

`run/generate_reference_compose.sh` regenerates Compose services from the TSV.

`run/run_preditr_compose.sh` is a convenience runner for non-computational users.

## Common commands

From the repository root:

```sh
docker compose -f run/compose.yaml up
```

or:

```sh
run/run_preditr_compose.sh
```

Then open:

```text
http://localhost:3838
```

Results written inside the container at `/outputs` appear on the host under:

```text
run/preditr_outputs/
```

To regenerate the root Compose file after editing organisms:

```sh
run/generate_reference_compose.sh
```

To regenerate the local copy:

```sh
run/generate_reference_compose.sh --output run/docker-compose.references.yml
```

To dry-run all reference image builds:

```sh
references/build_all_reference_images.sh --dry-run
```

To build all enabled reference images:

```sh
references/build_all_reference_images.sh
```

To build and push all enabled reference images:

```sh
references/build_all_reference_images.sh --push
```

To build one organism manually:

```sh
references/build_reference_image.sh \
  --organism human \
  --label Human \
  --genome-build GRCh38 \
  --image fvasquezcastro/preditr-ref:human-grch38 \
  --genome-package BSgenome.Hsapiens.UCSC.hg38 \
  --annotation-package TxDb.Hsapiens.UCSC.hg38.knownGene \
  --annotation-object TxDb.Hsapiens.UCSC.hg38.knownGene \
  --annotation-loader rds \
  --annotation-source-loader package-object \
  --annotation-transform txdb2grangeslist \
  --package BSgenome.Hsapiens.UCSC.hg38 \
  --package TxDb.Hsapiens.UCSC.hg38.knownGene
```

## Current code implications

The current PrEditR code still assumes a small fixed organism set in places such as:

- `functions/loadOrganismData.R`
- `PrEditR.R`
- Shiny UI organism choices and help text
- off-target indexed genome path selection in `server.R`

That means the Docker reference image work should be paired with a small internal reference adapter before adding many organisms.

The near-term adapter can be minimal:

1. Scan `/refs` for manifests.
2. Add each selected reference's `rlib` directory to `.libPaths()`.
3. Load the manifest's `genome_package`.
4. Load the manifest's annotation package/object.
5. Return the same shape currently returned by `loadOrganismData()`:

```r
list(
  txdb = txdb_object,
  genome = genome_object
)
```

This lets the workflow evolve without requiring raw FASTA/GTF uploads yet.

## First milestone

The first practical milestone should include only human and mouse:

- `preditr-ref:human-grch38`
- `preditr-ref:mouse-mm10`
- `preditr-shiny`
- a Compose file that starts the reference initializer containers and the app
- Shiny reference discovery from `/refs`

At this stage, do not allow user-uploaded FASTA/GTF references. Keep the UI curated and predictable.

## Expansion path

To add a new organism:

1. Identify the required Bioconductor packages.
2. Confirm that PrEditR can obtain the required genome and transcript annotation objects from those packages.
3. Add a row to `references/reference_organisms.tsv`.
4. Run `references/build_all_reference_images.sh --dry-run`.
5. Build the new reference image with `references/build_all_reference_images.sh`.
6. Regenerate Compose with `run/generate_reference_compose.sh`.
7. Confirm the Shiny app discovers the new manifest under `/refs`.
8. Add organism-specific adapter logic only if the generic manifest loader cannot load it.

The TSV columns are:

```text
organism
label
genome_build
image
bioc_version
platform
genome_package
annotation_package
annotation_object
annotation_loader
annotation_source_loader
annotation_transform
bioc_packages
cran_packages
enabled
```

Use `annotation_loader=data` when the annotation package exposes the object through `utils::data()`.

Use `annotation_loader=package-object` when the object is exported directly by the annotation package, as TxDb packages usually do.

Use `annotation_loader=rds` for the preferred normalized path. In that mode the image build loads the source annotation object using `annotation_source_loader`, applies `annotation_transform`, and saves `annotation/txdb.rds`.

Use `annotation_transform=txdb2grangeslist` to convert raw TxDb package objects into the `GRangesList` shape expected by PrEditR.

Use `none` for `cran_packages` when no CRAN packages are required.

The long-term target is still a real `PreditrReference` abstraction, but the reference-image contract above gives a controlled first step that works with the current Bioconductor package-based model.
