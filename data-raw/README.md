# data-raw/

Raw GEO data and the script that loads it into `StateTransitionData` objects.
The raw matrices and generated `.rds` files are intentionally not tracked.

## Files

| File | Contents |
|---|---|
| `load-aml-cml.R` | Source script — run with `Rscript data-raw/load-aml-cml.R` from repo root |
| `aml_mrna_std.rds` | AML mRNA, GSE133642, two layers (see below) |
| `cml_mrna_std.rds` | CML mRNA, GSE244990, single layer |
| `aml_multimodal_std.rds` | AML mRNA + miRNA, GSE133642 + GSE173785, 2018 source-paper training cohort |
| `geo/` | Raw GEO download files (not tracked in git) |
| `../inst/extdata/gse133642-sample-weeks.csv` | Public, minimal source-to-prepared mapping for authoritative AML observation weeks |

## AML mRNA layers (`aml_mrna_std.rds`)

Both layers are real biological validation data for landscapeR. The words
*training* and *validation* in this table describe their roles in the source
paper, not an acceptance claim for landscapeR.

| Prepared layer | Source cohort | Samples | landscapeR role |
|---|---|---:|---|
| `mrna_primary_2018` | `AML.mRNA.2018.all_samples`; source-paper training cohort | 132 | Defines the discovery state-space in the exploratory AML workflow |
| `mrna_supp_2016` | `AML.mRNA.2016`; source-paper validation cohort 1 | 101 | Hostile batch/time-confounded projection stress test after #24 |

The non-`validation` GSE133642 matrix contains the 132-observation 2018
source-paper training cohort. The GEO matrix whose filename contains
`validation` contains the 2016 validation experiments. Fifteen sparse `WK*`
observations from source-paper validation cohort 2 are excluded from the current
complete longitudinal cohort because they have no T0 observation. The loader
fails unless every retained expression column maps one-to-one to the packaged
source-time mapping.

## Authoritative longitudinal time

The only ordered-time field declared by the AML `SamplingDesign` is
`sample_weeks`; subject identity is `mouse_id` and the unit is `weeks`.
Categorical source labels remain inert metadata and are not used to derive,
interpolate, round, or order observations. No endpoint or event semantics are
introduced.

`sample_weeks` is copied exactly from the public `cohmathonc/haemdata` snapshot:

| Provenance item | Value |
|---|---|
| Repository | <https://github.com/cohmathonc/haemdata> |
| Source file | `data-raw/metadata_mmu.rds` |
| Immutable revision | `38176c1192989bbd5ec0f278d05aaaba06833567` |
| Source SHA-256 | `73977189d4979279b3fb7127dd28d29e7c2d7fe447844f05090c2aee78773f5f` |
| Source column | `sample_weeks` |
| Unit | weeks |
| Join key | `library_id`: `COHP_` plus the terminal numeric token of the GEO expression sample name |
| Packaged mapping | `inst/extdata/gse133642-sample-weeks.csv` |

The mapping contains only published mouse sample identifiers, source cohort,
prepared layer, mouse identity, and numeric weeks. It contains no dates,
endpoint field, or event inference.

## AML workflow boundary

The 2018 layer may be used by the future exploratory K=1 Stage 1 workflow after
its roadmap gates pass. The 2016 layer must not refit, rerank, or alter that
basis; projection remains blocked on #24. Repeated AML observations must not be
passed to the current cross-sectional Stage 2 estimator.

## GEO accessions

| Accession | Description |
|---|---|
| GSE133642 | AML mRNA (Cbfb-MYH11 mouse model) — Cancer Res 2020 |
| GSE173785 | AML miRNA — Sci Adv 2022 |
| GSE244990 | CML mRNA — Leukemia 2024 |
