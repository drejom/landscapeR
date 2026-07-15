# Issue #53 visual landing proof

**Claim status:** data-lineage and machinery-validation proof only. Both matrices
are real biological validation data for landscapeR, but this change makes no
biological, dynamics, endpoint, or strategy-acceptance claim.

## Cohort identity before and after

| Prepared layer | Before | After |
|---|---|---|
| `mrna_primary_2018` | 101-observation 2016 source-paper validation cohort, incorrectly labelled as 2018 primary | 132-observation `AML.mRNA.2018.all_samples` source-paper training cohort |
| `mrna_supp_2016` | 132-observation 2018 source-paper training cohort, incorrectly labelled as 2016 supplementary | 101-observation `AML.mRNA.2016` source-paper validation cohort 1 |
| 15 sparse `WK*` observations | Described as belonging to the 2018 matrix | Correctly identified as source-paper validation cohort 2 in the 2016 validation matrix and excluded from the current complete longitudinal cohort |

The source-paper role names describe the original analysis. Together, both
matrices are landscapeR's AML biological validation dataset. The 2018 layer will
define the exploratory discovery basis; the 2016 layer remains a later hostile
batch/time-confounded projection test.

## Authoritative numeric time

| Prepared layer | Observations | Mice | Exact source-week range | Non-integer observations | Missing | Mice strictly ordered |
|---|---:|---:|---:|---:|---:|---:|
| `mrna_primary_2018` | 132 | 14 | 0–43.6 | 76 | 0 | 14/14 |
| `mrna_supp_2016` | 101 | 16 | 0–31.0 | 81 | 0 | 16/16 |
| **Combined** | **233** | **30** | — | **157** | **0** | **30/30** |

The six source observations whose categorical label is `L` retain their source
weeks—25.9, 19.0, 19.0, 31.0, 19.0, and 13.4—without interpreting that label or
deriving time from it.

## Minimal longitudinal contract

| Field | Before | After |
|---|---|---|
| Subject | Present as `mouse_id`, not declared | `SamplingDesign@subject_id_col = "mouse_id"` |
| Ordered time | Authoritative values absent | `SamplingDesign@time_col = "sample_weeks"` |
| Unit | Undeclared | `weeks` |
| Event/endpoint | No general contract | Still none; no field or inference added |
| Categorical labels | Only available time-like metadata | Retained as inert source metadata; never used for ordering |

## Immutable lineage

The packaged mapping is extracted from
`cohmathonc/haemdata:data-raw/metadata_mmu.rds` at commit
`38176c1192989bbd5ec0f278d05aaaba06833567` (SHA-256
`73977189d4979279b3fb7127dd28d29e7c2d7fe447844f05090c2aee78773f5f`).
Every expression sample maps one-to-one by `library_id`; duplicates, unmatched
observations, missing values, and mouse-identity disagreements fail the loader.

## Reproduction

```sh
Rscript -e 'devtools::test(filter = "aml-data-preparation")'
Rscript data-raw/load-aml-cml.R
Rscript -e 'devtools::test()'
python3 scripts/check-roadmap.py
```

The generated `data-raw/*.rds` objects and raw GEO matrices remain ignored and
are not committed.
