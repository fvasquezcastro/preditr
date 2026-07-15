# Reference-image Dockerfiles

`build_reference_image.sh` generates the Dockerfile for each organism at build time and
now also **embeds the exact Dockerfile into each image** at
`/image-refs/<organism>/Dockerfile`, so every reference image self-documents how it was
produced. These committed files are the two canonical recipes, kept for review/diffing:

| file | recipe | organisms |
|------|--------|-----------|
| `standard.Dockerfile` | `TxDb2GRangesList(txdb)` (standardChromOnly defaults TRUE) | human, mouse, yeast, rat, fruitfly, celegans |
| `seqstyle-fix.Dockerfile` | `TxDb2GRangesList(txdb, standardChromOnly = FALSE)` | zebrafish, chicken |

## Why two recipes

The standard `txdb2grangeslist` transform calls
`GenomeInfoDb::keepStandardChromosomes(..., species = <organism>)`, which resolves the
species against the UCSC seqlevels-style registry. That registry has no entry for
*Danio rerio* (zebrafish) or *Gallus gallus* (chicken), so the call aborts in
`extractSeqlevels(species, "UCSC")`. Setting `standardChromOnly = FALSE` skips that
species lookup entirely; the trade-off is that the resulting `GRangesList` keeps every
contig the source `refGene` TxDb annotates (no standard-chromosome pruning).

Select the fix recipe at build time with `--standard-chrom-only false`.

## Notes

- These files are **generated** (representative ARG defaults: rat for standard,
  zebrafish for the fix). Do not hand-edit — regenerate from `build_reference_image.sh`.
  The per-image embedded copy carries that organism's real ARG values.
- The arabidopsis failure is a *different* problem (`biomaRt` doesn't recognize
  *Arabidopsis thaliana* — it's on the Ensembl Plants mart), not addressed by these
  recipes. See `references/docs/add-organisms-build-report.md`.
