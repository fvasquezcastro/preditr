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
(FASTA/GFF references are now buildable ahead of time via `--reference-kind fasta_gff` —
see "Building a reference from a genome FASTA + annotation" below — but that is an
operator-side image build, not a runtime upload in the Shiny UI.)

## Building a reference before its maps exist

The genome + annotation payload (BSgenome package plus the `GRangesList` written to
`annotation/txdb.rds`) is built entirely from Bioconductor packages and does **not**
require the `maps/<organism>/` ID-mapping tables. Those maps are produced separately
(from biomart/UniProt) and copied into the image only at the final `COPY maps` step.

This means a reference image can be built and fully validated (genome `getSeq`,
CDS translation, `GRangesList` feature/`tx_id`/`gene_symbol` checks) before its maps
are available. Two build flags enable this:

- `--allow-non-builtin` → sets `PREDITR_ALLOW_NON_BUILTIN_REFERENCE=TRUE`, permitting
  organism ids other than `human`/`mouse` past the compatibility gate.
- `--allow-missing-maps` → sets `PREDITR_ALLOW_MISSING_MAPS=TRUE`, downgrading the
  missing-`maps/<organism>` error to a NOTE. The genome and annotation are still
  validated in full.

`build_all_reference_images.sh` passes both flags automatically: `--allow-non-builtin`
for any organism that is not `human`/`mouse`, and `--allow-missing-maps` whenever
`maps/<organism>/` is absent in the repo.

To add maps later, drop the files into `maps/<organism>/` and rebuild. Because the
`COPY maps` step sits near the end of the Dockerfile — after every package install —
Docker reuses the cached layers up to that point, so the rebuild is cheap.

> The maps must contain the objects the runtime expects: `uniprot_to_ensembl.rds`,
> `ensembl_to_uniprot.rds`, and `has_isoforms.rds`, each an R environment. When maps
> are present the compatibility check enforces this; when they are absent (build-only
> mode) it does not.

> Building the image only produces a validated reference on the shelf. The running
> app still dispatches through `loadOrganismData.R` and `PrEditR.R`. `generatePrettyTable.R`
> is no longer a blocker: its gene-symbol linking is now `human` → GeneCards,
> `mouse` → MGI, and every other organism → a plain (non-linked) gene-symbol pill, so
> the mouse-only `mapEnsembl2MGI()` path is never hit for custom organisms.

## Building a reference from a genome FASTA + annotation (reference-kind fasta_gff)

For organisms with no suitable Bioconductor `BSgenome`/`TxDb` packages, a reference can
be built directly from a genome **FASTA** plus an annotation **GFF3/GTF**, with an
optional UniProt↔transcript map to enable UniProt-ID input. This is the `fasta_gff`
reference kind of `build_reference_image.sh`:

```sh
references/build_reference_image.sh \
  --reference-kind fasta_gff \
  --organism newt --label "Newt" --genome-build newt1 \
  --image fvasquezcastro/preditr-ref:newt-newt1 \
  --genome-fasta   /data/newt.fa \
  --annotation-gff /data/newt.gff3 \
  --uniprot-map    /data/newt_uniprot.tsv   # optional
```

What the build does (all inside the Bioconductor builder stage, producing the **same**
payload contract as the package path — a BSgenome package in `rlib/` plus a normalized
`GRangesList` at `annotation/txdb.rds`):

1. **Genome**: trims FASTA seqnames at the first whitespace (so `>chr1 description`
   becomes `chr1`, matching GFF seqnames) → `rtracklayer::export.2bit` →
   `BSgenomeForge::forgeBSgenomeDataPkgFromTwobitFile` → `R CMD INSTALL` into `rlib/`.
   The forged package name is auto-derived from `--genome-organism`/`--provider`/
   `--genome-build` and read back into the manifest — it is not chosen by the caller.
2. **Annotation**: `txdbmaker::makeTxDbFromGFF(organism = NA)` →
   `crisprDesign::TxDb2GRangesList` (respecting `--standard-chrom-only`), then a
   normalization pass that (a) strips GFF type prefixes so `tx_id`/`gene_id` are bare
   (e.g. `transcript:ENST…` → `ENST…`, matching the UniProt map and user input), and
   (b) injects `gene_symbol` from the GFF `Name`/`gene_name` attribute (falling back to
   `gene_id`), because `TxDb2GRangesList` leaves `gene_symbol` `NA` for organisms with
   no OrgDb.
3. **Maps** (only with `--uniprot-map`): `generate_reference_maps.R --uniprot-map`
   builds `uniprot_to_ensembl.rds` / `ensembl_to_uniprot.rds` / `has_isoforms.rds`
   (etc.) from the TSV, filtered to the transcripts present in the annotation.

`--reference-kind fasta_gff` implies `--allow-non-builtin` (a custom organism is never
`human`/`mouse`), and implies `--allow-missing-maps` when no `--uniprot-map` is given
(the reference then builds without maps and UniProt-ID input is disabled; Ensembl/GFF
transcript IDs still work).

The **UniProt map TSV** has columns:

| column | required | meaning |
|---|---|---|
| `transcript_id` | yes | matches the GFF transcript IDs (bare, no `transcript:` prefix) |
| `uniprot_id` | yes | UniProt accession; use the `-N` isoform accession on isoform rows |
| `is_canonical` | no | `1` for the canonical transcript of a base accession, else `0`/blank |
| `isoform_of` | no | for isoform rows, the base Swiss-Prot accession the isoform belongs to |

The resulting payload passes the unmodified `check_reference_compatibility.R` and loads
through `loadReference()` exactly like a package-based reference. As with any new
organism, the row stays `enabled=false` in the registry until validated in the running
app; `reference_organisms.tsv` describes package-based organisms, so FASTA/GFF
references are built by invoking `build_reference_image.sh` directly (they are not
driven from the TSV).

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
