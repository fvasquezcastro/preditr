# Runbook: building reference images for additional organisms

This runbook lets a fresh session build the additional-organism reference images
(arabidopsis, C. elegans, fruit fly, zebrafish, chicken, rat, yeast) using the same
lightweight two-stage strategy as human/mouse. Maps are **not** required to build —
they are supplied separately and added by rebuilding later.

Read `references/docs/compose-reference-images.md` first for the overall design and
the reference-image contract. This file is the operational how-to.

## Status (2026-07-14: 6 of 7 built & pushed; arabidopsis skipped)

Six organisms are built on the Docker Build Cloud builder and pushed to Docker Hub. **The
BSgenome + TxDb package names in `reference_organisms.tsv` are all valid for Bioc 3.19** —
every genome/annotation package installed cleanly. The failure modes live in the same step,
`crisprDesign::TxDb2GRangesList()` (the raw-TxDb → `GRangesList` transform): the
seqstyle-registry gap (zebrafish, chicken) is now **fixed**; arabidopsis is **skipped**
(biomaRt gap plus other stacked issues — not fixed).

Built, pushed, and verified (manifest + `annotation/txdb.rds` present):

| organism  | image                                          | size    | note |
|-----------|------------------------------------------------|---------|------|
| yeast     | `fvasquezcastro/preditr-ref:yeast-saccer3`     | 478 MB  | leaner rebuild (was ~689 MB) |
| rat       | `fvasquezcastro/preditr-ref:rat-rn7`           | 1.77 GB | |
| fruitfly  | `fvasquezcastro/preditr-ref:fruitfly-dm6`      | 552 MB  | |
| celegans  | `fvasquezcastro/preditr-ref:celegans-ce11`     | 532 MB  | |
| zebrafish | `fvasquezcastro/preditr-ref:zebrafish-danrer11`| 1.3 GB  | seqstyle fix (`--standard-chrom-only false`) |
| chicken   | `fvasquezcastro/preditr-ref:chicken-galgal6`   | 994 MB  | seqstyle fix (`--standard-chrom-only false`) |

**Seqstyle fix (zebrafish, chicken):** their species (*Danio rerio*, *Gallus gallus*) have
no GenomeInfoDb UCSC seqlevels-style entry, so the default transform aborted in
`keepStandardChromosomes(species=...) → extractSeqlevels(species,"UCSC")`. Fixed by the new
`--standard-chrom-only false` flag, which passes `standardChromOnly = FALSE` to
`TxDb2GRangesList` and skips that species lookup (trade-off: keeps all contigs, hence the
larger images). These two images embed their exact Dockerfile at
`/image-refs/<org>/Dockerfile`; the two canonical recipes are committed under
`references/dockerfiles/` (see its README).

Skipped (not built, not pushed):

| organism    | why skipped                                                                  |
|-------------|------------------------------------------------------------------------------|
| arabidopsis | `.getBiomartData` — "Organism 'Arabidopsis thaliana' not recognized in biomaRt" (plant; Ensembl Plants mart), plus a UCSC seqlevelsStyle gap and a TxDb-vs-BSgenome seqname mismatch. Deliberately skipped; the `--standard-chrom-only` fix does not apply. |

See `references/docs/add-organisms-build-report.md` for the full analysis and a sketch of a
bespoke transform that could fix it later.

- All 7 rows remain `enabled=false` on purpose. The immediate reason the six built images
  stay disabled is that **their map files are missing** — they were built with
  `--allow-missing-maps`, so ID mapping would not work at runtime (plus the app still lacks
  a generic reference adapter). See "Why enabled=false". So `run/compose.yaml` regenerates
  with only human + mouse. Arabidopsis was skipped and additionally needs a new
  custom-transform path, not a TSV package-name change.

## What was already changed in the repo

1. `references/reference_organisms.tsv` — 7 new rows (all `enabled=false`), using the
   `TxDb → txdb2grangeslist` annotation path (crisprDesignData only ships human/mouse
   objects, so other organisms convert a raw UCSC/BioMart TxDb at build time).
2. `references/build_reference_image.sh` — new flags:
   - `--allow-non-builtin` → sets `PREDITR_ALLOW_NON_BUILTIN_REFERENCE=TRUE` (lets the
     compatibility gate accept organism ids other than human/mouse).
   - `--allow-missing-maps` → sets `PREDITR_ALLOW_MISSING_MAPS=TRUE` (downgrades the
     missing-`maps/<organism>` error to a NOTE; genome + annotation still fully validated).
   - Build-only dependency routing: `crisprDesign` and the source `TxDb` install into the
     builder's default library and are kept **out of** the shipped `rlib`. Only the
     BSgenome package (+ its runtime deps) and `annotation/txdb.rds` ship. This mirrors
     how `crisprDesignData` is treated build-only for human/mouse and keeps images small.
3. `references/build_all_reference_images.sh` — auto-passes `--allow-non-builtin` for any
   non-human/mouse organism and `--allow-missing-maps` when `maps/<organism>/` is absent.
   (Still only builds `enabled=true` rows.)
4. `references/check_reference_compatibility.R` — missing maps is a NOTE (not fatal) when
   `PREDITR_ALLOW_MISSING_MAPS` is set.

## Proposed packages per organism (confirm against Bioc 3.19 at build time)

| organism    | genome_build | BSgenome                          | TxDb (source annotation)              |
|-------------|--------------|-----------------------------------|---------------------------------------|
| yeast       | sacCer3      | BSgenome.Scerevisiae.UCSC.sacCer3 | TxDb.Scerevisiae.UCSC.sacCer3.sgdGene |
| rat         | rn7          | BSgenome.Rnorvegicus.UCSC.rn7     | TxDb.Rnorvegicus.UCSC.rn7.refGene     |
| zebrafish   | danRer11     | BSgenome.Drerio.UCSC.danRer11     | TxDb.Drerio.UCSC.danRer11.refGene     |
| fruitfly    | dm6          | BSgenome.Dmelanogaster.UCSC.dm6   | TxDb.Dmelanogaster.UCSC.dm6.ensGene   |
| celegans    | ce11         | BSgenome.Celegans.UCSC.ce11       | TxDb.Celegans.UCSC.ce11.refGene       |
| chicken     | galGal6      | BSgenome.Ggallus.UCSC.galGal6     | TxDb.Ggallus.UCSC.galGal6.refGene     |
| arabidopsis | TAIR9        | BSgenome.Athaliana.TAIR.TAIR9     | TxDb.Athaliana.BioMart.plantsmart28   |

These names live in `references/reference_organisms.tsv`; edit there, not here.

## Build all remaining organisms

The committed `build_all_reference_images.sh` skips `enabled=false` rows, so use this
loop, which builds every non-human/mouse row directly regardless of the flag. Run from
the repo root. `--context` should match your active Docker context (`docker context show`;
Docker Desktop on Linux is usually `desktop-linux`).

```sh
CTX="$(docker context show)"
CONFIG=references/reference_organisms.tsv
LOGDIR="$(mktemp -d)/preditr-builds"; mkdir -p "$LOGDIR"
echo "logs: $LOGDIR"

tail -n +2 "$CONFIG" | while IFS=$'\t' read -r organism label genome_build image bioc_version platform \
  genome_package annotation_package annotation_object annotation_loader \
  annotation_source_loader annotation_transform bioc_packages cran_packages github_packages enabled; do
  [ -z "$organism" ] && continue
  case "$organism" in \#*|human|mouse) continue;; esac

  cmd=(references/build_reference_image.sh
    --organism "$organism" --label "$label" --genome-build "$genome_build"
    --image "$image" --bioc-version "$bioc_version" --platform "$platform"
    --genome-package "$genome_package"
    --annotation-package "$annotation_package" --annotation-object "$annotation_object"
    --annotation-loader "$annotation_loader"
    --annotation-source-loader "$annotation_source_loader"
    --annotation-transform "$annotation_transform"
    --allow-non-builtin --allow-missing-maps --context "$CTX")

  IFS=',' read -r -a a <<< "$bioc_packages";  for p in "${a[@]}"; do [ -n "$p" ] && [ "$p" != none ] && cmd+=(--package "$p"); done
  IFS=',' read -r -a a <<< "$cran_packages";  for p in "${a[@]}"; do [ -n "$p" ] && [ "$p" != none ] && cmd+=(--cran-package "$p"); done
  IFS=',' read -r -a a <<< "$github_packages";for p in "${a[@]}"; do [ -n "$p" ] && [ "$p" != none ] && cmd+=(--github-package "$p"); done

  echo "=== $organism -> $image ==="
  if "${cmd[@]}" > "$LOGDIR/$organism.log" 2>&1; then echo "  OK   $organism"; else echo "  FAIL $organism (see $LOGDIR/$organism.log)"; fi
done
```

Build one organism manually (example, yeast):

```sh
references/build_reference_image.sh \
  --organism yeast --label "Yeast" --genome-build sacCer3 \
  --image fvasquezcastro/preditr-ref:yeast-saccer3 \
  --genome-package BSgenome.Scerevisiae.UCSC.sacCer3 \
  --annotation-package TxDb.Scerevisiae.UCSC.sacCer3.sgdGene \
  --annotation-object TxDb.Scerevisiae.UCSC.sacCer3.sgdGene \
  --annotation-loader rds --annotation-source-loader package-object \
  --annotation-transform txdb2grangeslist \
  --package BSgenome.Scerevisiae.UCSC.sacCer3 \
  --package TxDb.Scerevisiae.UCSC.sacCer3.sgdGene \
  --allow-non-builtin --allow-missing-maps --context "$(docker context show)"
```

Dry-run any build (prints the generated Dockerfile + docker command, builds nothing):
add `--dry-run`.

## Verify a built image

```sh
IMG=fvasquezcastro/preditr-ref:yeast-saccer3   # adjust tag
docker run --rm --entrypoint sh "$IMG" -c '
  o=$(ls /image-refs); echo "organism: $o";
  cat /image-refs/$o/preditr_reference.json; echo;
  ls -lh /image-refs/$o/annotation/txdb.rds;
  ls /image-refs/$o/maps 2>/dev/null || echo "(no maps yet)"'
docker image ls "$IMG" --format '{{.Tag}} {{.Size}}'
```

A green build means the compatibility check inside the build passed: genome `getSeq`,
CDS translation, and the `GRangesList` feature/`tx_id`/`gene_symbol` checks. The two
expected NOTEs are the missing maps and the `generatePrettyTable`/`mapEnsembl2MGI` caveat.

## If a build fails

Read `"$LOGDIR/<organism>.log"`. Most likely causes and fixes:

- **Package not available for Bioc 3.19** (`... is not available` / not found). Find the
  correct BSgenome/TxDb name+build for release 3.19 and update that row in
  `reference_organisms.tsv` (e.g. a different genome build suffix). Do not query external
  biomart/UniProt — this is Bioconductor package selection only.
- **Missing `gene_symbol` on CDS** (ERROR from the compatibility check). yeast did not hit
  this, but if another organism's `TxDb2GRangesList` output lacks `gene_symbol`, add the
  organism's OrgDb (e.g. `org.Dm.eg.db`) as a build-only package and extend the annotation
  transform to populate `gene_symbol` from it, then rebuild.
- **CDS/genome seqname mismatch** (e.g. Ensembl-vs-UCSC chromosome naming). Prefer a TxDb
  whose seqnames match the chosen BSgenome (both UCSC), or add a seqlevels-style fix to the
  transform.
- **`extractSeqlevels(species, "UCSC")` has no compatible entry** (ERROR in
  `TxDb2GRangesList` → `keepStandardChromosomes` → `standardChromosomes`). The species has
  no GenomeInfoDb UCSC seqlevels-style entry (seen for *Danio rerio*/zebrafish and
  *Gallus gallus*/chicken). Rebuild that organism with `--standard-chrom-only false`, which
  passes `standardChromOnly = FALSE` to `TxDb2GRangesList` and skips the species lookup
  (keeps all contigs). See `references/dockerfiles/seqstyle-fix.Dockerfile`.
- **`.getBiomartData ... not recognized in biomaRt`** (ERROR in `TxDb2GRangesList`). The
  transform enriches gene symbols via a live Ensembl biomaRt call; some organisms (e.g.
  *Arabidopsis thaliana*, on the Ensembl Plants mart) are not on the default mart. No flag
  yet — needs a transform that sources symbols from the organism OrgDb or the correct mart.
  (Also a transient Ensembl outage can produce a "service currently unavailable" variant —
  just retry.)

## Adding maps later (no rebuild of the heavy layers)

Maps are the ID-mapping tables (`uniprot_to_ensembl.rds`, `ensembl_to_uniprot.rds`,
`has_isoforms.rds`, each an R environment; plus optional `plddt.rds`), built separately
from biomart/UniProt and provided by the user. To attach them:

1. Drop the files into `maps/<organism>/` in the repo.
2. Rebuild that organism's image (same command as above; you can drop
   `--allow-missing-maps` once maps exist so the check enforces map contents).

Because `COPY maps` is the last meaningful step in the Dockerfile, Docker reuses all
cached layers up to it, so this rebuild is fast.

## Why enabled=false

Building an image only produces a validated reference on the shelf. The running app still
dispatches through code hardcoded to human/mouse:

- `functions/loadOrganismData.R` — only `human`/`mouse` branches.
- `PrEditR.R:232` — organism branch.
- `functions/generatePrettyTable.R:13-30` — treats every non-human organism as mouse and
  calls `mapEnsembl2MGI()`.

These need a generic reference adapter (scan `/refs/*/preditr_reference.json`, add the
manifest's `rlib` to `.libPaths()`, load genome package + `txdb.rds`) before a new organism
can actually run in the app. Until then keep the new rows `enabled=false`; the Compose
generator (`run/generate_reference_compose.sh`) only wires `enabled=true` organisms.

**Also: the built images have no map files yet.** All six were built with
`--allow-missing-maps` (there is no `maps/<organism>/` in the repo), so their reference
directories ship without the ID-mapping tables (`uniprot_to_ensembl.rds`,
`ensembl_to_uniprot.rds`, `has_isoforms.rds`). PrEditR's core input is a UniProt/Ensembl ID,
so without these maps the organism cannot resolve targets at runtime. This alone is reason
to keep the rows `enabled=false` until maps are supplied (see "Adding maps later"), even
before the generic adapter lands.

## Publishing images

Add `--push` to the build (needs `docker login` for the target registry). Then regenerate
Compose after flipping any organism to `enabled=true`:

```sh
run/generate_reference_compose.sh
```
