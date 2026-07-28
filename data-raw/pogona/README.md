# Pogona RNA-seq data

This directory consolidates three destructive-sampling RNA-seq experiments for
future landscapeR analysis. The compact merged matrices and Sarah Whiteley's
audited master sequencing registry are kept locally and ignored by Git.
Normalized canonical-sample manifests, acquisition code, source paths, source
digest, and validation flags are tracked.

## Experiments

| Directory | Design | Local matrices |
|---|---|---|
| `gsd_timecourse_28c` | 28 C ZZ and ZW samples at days 7, 9, 11, 13, 15, and 17 | merged gene counts and TPM |
| `early_urogenital_28c` | Whole urogenital systems at stages 1, 2, and 4; 28 C ZZ and ZW | merged gene counts and TPM |
| `gonad_temperature` | Gonads at stages 6, 12, and 15; 28 C ZZ, 28 C ZW, and 36 C ZZ | merged gene counts and TPM |

Run from the package root:

```sh
data-raw/pogona/sync-from-gadi.sh
python3 data-raw/pogona/build-metadata.py
```

The metadata builder treats one matrix column as one canonical biological
observation. It writes one `sample_metadata.csv` beside each pair of ignored
matrices and fails if the audited registry digest changes, count/TPM columns
differ, matrix columns are duplicated, or expected experiment counts drift.
Sequencing-library identifiers, specimen identifiers, confidence fields,
registry references, pooling, and defects remain visible as provenance without
turning library rows into independent biological observations.

## Source registry

| Item | Value |
|---|---|
| Local ignored source | `source_metadata/MASTER_pogona_sequencing_SLIM.csv` |
| SHA-256 | `5a450ef02f148c2fc275b048dca58f51b72fbef0590509450c49a91c8ae147dc` |
| Join | `matrix_columns`, using the experiment-specific matrix namespace |
| Canonical unit | one merged-matrix column |

## Current eligibility

| Experiment | Matrix columns | Included | Excluded pending clarification |
|---|---:|---:|---:|
| `gsd_timecourse_28c` | 35 | 33 | 2 |
| `early_urogenital_28c` | 17 | 17 | 0 |
| `gonad_temperature` | 83 | 76 | 7 |

The two time-course exclusions retain the registry's
`DEG_ID_inconsistent_with_GROUP` flag. The seven gonad exclusions comprise
three body/gonad identity conflicts, one unresolved `F` genotype, one
organ-culture sample in the gonad matrix, and two matrix columns with multiple
library mappings. Questions covering all seven records have been sent to the
data owner. They remain excluded until the source registry is corrected or a
documented resolution is supplied.

## Data boundary

Only merged gene-level count and TPM matrices are copied. The full master
registry remains local because it covers unrelated experiments and contains
administrative, date, family, and facility fields outside the analysis
boundary. BAMs, bigWigs, per-sample Salmon directories, and those registry
fields are not committed.
