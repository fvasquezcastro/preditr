# Organism reference image build — running findings

Build: cloud builder `cloud-fvasquezcastro-builder8`, parallel (MAX_JOBS=4), `--push` to Docker Hub.
Flags per organism: `--allow-non-builtin --allow-missing-maps` (no maps/<organism> in repo).
No edits made to build_reference_image.sh or any script.

## Results — 4 OK / 3 FAIL

| organism | status | image (Docker Hub) | pulled size | txdb.rds |
|----------|--------|--------------------|-------------|----------|
| yeast | OK (pushed, verified) | fvasquezcastro/preditr-ref:yeast-saccer3 | 478 MB | 418 K |
| rat | OK (pushed, verified) | fvasquezcastro/preditr-ref:rat-rn7 | 1.77 GB | 6.8 M |
| fruitfly | OK (pushed, verified) | fvasquezcastro/preditr-ref:fruitfly-dm6 | 552 MB | 5.4 M |
| celegans | OK (pushed, verified) | fvasquezcastro/preditr-ref:celegans-ce11 | 532 MB | 6.2 M |
| zebrafish | FAIL | — | — | seqstyle gap (below) |
| chicken | FAIL | — | — | seqstyle gap (below) |
| arabidopsis | FAIL | — | — | biomaRt gap (below) |

All 4 OK images verified: manifest well-formed, `annotation/txdb.rds` present (GRangesList),
`maps` absent as expected (build-only mode). The compatibility check inside each build
(genome getSeq, CDS translation, GRangesList feature/tx_id/gene_symbol) passed.

## Cross-cutting finding

All 3 failures die at the SAME Dockerfile step (builder 8/16), inside
`crisprDesign::TxDb2GRangesList()` — the raw-TxDb → GRangesList transform. The BSgenome
and TxDb packages installed cleanly for every organism; the package names in
`reference_organisms.tsv` are all valid for Bioc 3.19. The transform has two hidden
requirements that the 4 passing organisms happen to satisfy and the 3 failing ones do not:

1. A GenomeInfoDb UCSC seqlevels-style entry for the species (needed by
   `standardChromosomes()` → `extractSeqlevels(species, "UCSC")`).
   Missing for **Danio rerio** (zebrafish) and **Gallus gallus** (chicken).
2. A biomaRt-recognized organism for gene-symbol enrichment (`.getBiomartData`), which
   also implies a **build-time network call** to Ensembl biomaRt.
   Fails for **Arabidopsis thaliana** (served by the separate Ensembl Plants mart).

So the current `txdb2grangeslist` path works for well-covered UCSC/Ensembl-vertebrate/fungal
species but not for these three. Fixing them means changing the transform (out of scope for
this run per instructions).

## Failures — cause + suggested fix (not applied)

### zebrafish (danRer11)
Step: builder 8/16, `crisprDesign::TxDb2GRangesList(txdb)`.
Error:
```
Error in extractSeqlevels(species, style) :
  The style specified by 'UCSC' does not have a compatible entry for the species Danio rerio
Calls: <Anonymous> ... standardChromosomes -> extractSeqlevels
```
Cause: `TxDb2GRangesList` calls `GenomeInfoDb::standardChromosomes()`, which looks up a
UCSC seqlevels-style entry for the species "Danio rerio". That registry entry is absent
in this GenomeInfoDb (Bioc 3.19), so the transform aborts. Not a package-name problem;
the TxDb + BSgenome installed fine.
Suggested fix (later, needs a transform/patch — deliberately NOT done here to avoid
per-build script edits):
 - Set an explicit seqlevelsStyle / drop nonstandard scaffolds on the TxDb before the
   transform, or pin seqnames to the BSgenome's standard chromosomes, or
 - Use a GenomeInfoDb with a Danio rerio UCSC mapping, or supply a custom
   `TxDb2GRangesList` path that skips `standardChromosomes()`.

### arabidopsis (TAIR9)
Step: builder 8/16, `crisprDesign::TxDb2GRangesList(txdb)`.
Error:
```
Error in .getBiomartData(txdb, organism) :
  Organism 'Arabidopsis thaliana' not recognized in biomaRt.
Calls: <Anonymous> -> .TxDb2GRangesList -> .getBiomartData
```
Cause: `TxDb2GRangesList` enriches the GRangesList by querying biomaRt for gene symbols,
and its organism lookup does not recognize "Arabidopsis thaliana" (plant, served by a
separate biomaRt mart — plants.ensembl.org — that crisprDesign's default path does not use).
Also implies a build-time network call to biomaRt. TxDb + BSgenome installed fine.
Suggested fix (later, NOT done here — would need a transform/script change):
 - Supply gene symbols from the plant OrgDb (org.At.tair.db) instead of biomaRt, i.e. a
   custom transform that builds the GRangesList without `.getBiomartData`, or
 - Point crisprDesign at the Ensembl Plants mart for Arabidopsis.
Note: TAIR9 (2009) is also quite old; a newer TAIR build + matching TxDb may be preferable
regardless.

### chicken (galGal6)
Step: builder 8/16, `crisprDesign::TxDb2GRangesList(txdb)`.
Error:
```
Error in extractSeqlevels(species, style) :
  The style specified by 'UCSC' does not have a compatible entry for the species Gallus gallus
Calls: <Anonymous> ... standardChromosomes -> extractSeqlevels
```
Cause: identical to zebrafish — GenomeInfoDb has no UCSC seqlevels-style entry for
"Gallus gallus", so `standardChromosomes()` inside the transform aborts. TxDb + BSgenome
installed fine.
Suggested fix: same as zebrafish (set seqlevelsStyle / restrict to standard chromosomes
before the transform, or use a GenomeInfoDb with a Gallus gallus UCSC mapping).
