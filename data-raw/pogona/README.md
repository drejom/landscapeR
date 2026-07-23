# Pogona RNA-seq data

This directory consolidates three destructive-sampling RNA-seq experiments for
future landscapeR analysis. The compact merged matrices are kept locally and
ignored by Git. Normalized metadata, acquisition code, source paths, and
validation flags are tracked.

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

The metadata builder writes one `sample_metadata.csv` beside each pair of
ignored matrices and fails if matrix/TPM columns differ or an expected mapping
is absent. It retains unmatched gonad matrix columns with `include = false` and
an explicit reason.

## Known metadata issue

The supplied time-course workbook labels two rows `ZZ_7_Rep2` and `ZZ_7_Rep3`
in `DEG_ID`, while their `GROUP` and external identifiers say `ZZ_9`. The
normalized metadata marks these rows `group_deg_conflict`; it does not silently
choose one label. This must be resolved with the data owner before analysis.

## Data boundary

Only merged gene-level count and TPM matrices are copied. BAMs, bigWigs,
per-sample Salmon directories, and administrative fields from the sequencing
manifest are outside this repository boundary.
