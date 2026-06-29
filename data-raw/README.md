# data-raw/

Raw GEO data and the script that loads it into `StateTransitionData` objects.

## Files

| File | Contents |
|---|---|
| `load-aml-cml.R` | Source script — run with `Rscript data-raw/load-aml-cml.R` from repo root |
| `aml_mrna_std.rds` | AML mRNA, GSE133642, two layers (see below) |
| `cml_mrna_std.rds` | CML mRNA, GSE244990, single layer |
| `aml_multimodal_std.rds` | AML mRNA + miRNA, GSE133642 + GSE173785, primary cohort only |
| `geo/` | Raw GEO download files (not tracked in git) |

## AML mRNA layers (`aml_mrna_std.rds`)

| Layer name | Cohort | Samples | Note |
|---|---|---|---|
| `mrna_primary_2018` | Primary experiment | 101 | Clean randomised batches, reported in paper. **Use this for Stage 1 SVD.** |
| `mrna_supp_2016` | Supplementary | 132 | Batch-confounded earlier experiment. Project into primary state-space via `project_into()`. |

**Important:** The GEO depositor labelled the 2016 file without "validation" and the 2018
file as "validation" — the reverse of scientific primacy. In the paper, the 2018 cohort is
the training cohort (SVD is built on these mice); the 2016 cohort is the supplementary
stress-test (projected in as a validation of the state-space).

15 WK10–WK28 samples are dropped from the 2018 data: they come from a separate arm
(mice 3127/3130/3131/3200/3202), have no T0 baseline, and their library prep is
confounded with timepoint.

## Typical usage

```r
library(landscapeR)
aml  <- readRDS("data-raw/aml_mrna_std.rds")

# Stage 1 on primary cohort (layer 1)
s1   <- decompose(get_strategy("Decomposer", "hogsvd_averaged"), aml)
std  <- s1@value

# Gallery — identify which component carries the state-transition signal
plot_components(std, colour_by = "condition")

# Project supplementary 2016 cohort into the primary state-space
aml_supp <- StateTransitionData(
  experiments = list(mrna_supp_2016 = experiments(aml)[["mrna_supp_2016"]]),
  colData     = colData(aml)[colData(aml)$cohort == "supp_2016", ]
)
aml_supp_proj <- project_into(std, aml_supp)
plot_components(aml_supp_proj, colour_by = "condition")
```

## GEO accessions

| Accession | Description |
|---|---|
| GSE133642 | AML mRNA (Cbfb-MYH11 mouse model) — Cancer Res 2020 |
| GSE173785 | AML miRNA — Sci Adv 2022 |
| GSE244990 | CML mRNA — Leukemia 2024 |
