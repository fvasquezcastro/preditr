# Organism reference image build — running findings

Build: cloud builder `cloud-fvasquezcastro-builder8`, parallel, `--push` to Docker Hub.
Flags per organism: `--allow-non-builtin --allow-missing-maps` (no maps/<organism> in repo).

**Phase 1** (first pass): built all 7 with no script edits — 4 OK, 3 FAIL.
**Phase 2** (seqstyle fix): zebrafish + chicken rebuilt with `--standard-chrom-only false`
(new flag) — both now OK. Arabidopsis remains failing (different, biomaRt cause).

## Results — 6 OK / 1 FAIL (after seqstyle fix)

| organism | status | image (Docker Hub) | pulled size | txdb.rds |
|----------|--------|--------------------|-------------|----------|
| yeast | OK (pushed, verified) | fvasquezcastro/preditr-ref:yeast-saccer3 | 478 MB | 418 K |
| rat | OK (pushed, verified) | fvasquezcastro/preditr-ref:rat-rn7 | 1.77 GB | 6.8 M |
| fruitfly | OK (pushed, verified) | fvasquezcastro/preditr-ref:fruitfly-dm6 | 552 MB | 5.4 M |
| celegans | OK (pushed, verified) | fvasquezcastro/preditr-ref:celegans-ce11 | 532 MB | 6.2 M |
| zebrafish | OK (fixed, pushed, verified) | fvasquezcastro/preditr-ref:zebrafish-danrer11 | 1.3 GB | 6.6 M |
| chicken | OK (fixed, pushed, verified) | fvasquezcastro/preditr-ref:chicken-galgal6 | 994 MB | 2.6 M |
| arabidopsis | FAIL | — | — | biomaRt gap (below) |

All 6 OK images verified: manifest well-formed, `annotation/txdb.rds` present (GRangesList),
`maps` absent as expected (build-only mode). The compatibility check inside each build
(genome getSeq, CDS translation, GRangesList feature/tx_id/gene_symbol) passed. The two
fixed images additionally embed their exact Dockerfile at `/image-refs/<org>/Dockerfile`
(showing `TxDb2GRangesList(txdb, standardChromOnly = FALSE)`).

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
species but not for these three. The seqstyle issue (1) is fixed in Phase 2; the biomaRt
issue (2) still blocks arabidopsis.

## Phase 2 — seqstyle fix (applied)

Fixed zebrafish and chicken by passing `standardChromOnly = FALSE` to
`crisprDesign::TxDb2GRangesList()`. That argument skips
`GenomeInfoDb::keepStandardChromosomes(species = ...)`, the call that resolved the species
against the UCSC seqlevels-style registry and aborted in `extractSeqlevels()`. Verified
in a container first: default `TRUE` reproduced the exact error, `FALSE` got past it.

Implementation (no per-organism hacks; a general, documented lever):
- `build_reference_image.sh`: new `--standard-chrom-only true|false` flag (default `true`,
  so all other organisms are unchanged). Also now embeds the exact Dockerfile into every
  image at `/image-refs/<org>/Dockerfile`.
- `references/dockerfiles/standard.Dockerfile` and `seqstyle-fix.Dockerfile` committed as
  the two canonical recipes (they differ only in the `TxDb2GRangesList` call); see
  `references/dockerfiles/README.md`.

Trade-off: `standardChromOnly = FALSE` keeps every contig the source `refGene` TxDb
annotates (no standard-chromosome pruning). Harmless for guide design; it makes the
zebrafish/chicken images somewhat larger (1.3 GB / 994 MB).

## Failures — cause + fix

### zebrafish (danRer11) — RESOLVED in Phase 2
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
Fix applied (Phase 2): `--standard-chrom-only false`. Built, pushed, verified.

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

### chicken (galGal6) — RESOLVED in Phase 2
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
Fix applied (Phase 2): `--standard-chrom-only false`. Built, pushed, verified.
