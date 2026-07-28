# Issue #101 landing proof

This packet records the canonical Pogona manifest transition produced by
reconciling the three local expression matrices with Sarah Whiteley's audited
master sequencing registry.

## Analysis boundary

| Property | Before | After |
|---|---|---|
| Metadata source | Two earlier experiment-specific files plus matrix-label parsing | One checksum-verified audited master registry |
| Canonical observation | Matrix column | Matrix column |
| Sequencing libraries | Partially represented | Retained as provenance; never promoted to biological replicates |
| Declared tissue pools | Generic sample-or-pool label | Explicitly identified as pooled canonical observations |
| Unresolved records | Excluded with earlier incomplete mappings | Excluded with registry-backed reasons and defect flags |
| Full source registry | Local and ignored | Local and ignored |

## Eligibility transition

| Canonical experiment | Matrix columns | Included before | Included after | Still excluded |
|---|---:|---:|---:|---:|
| `gsd_timecourse_28c` | 35 | 33 | 33 | 2 |
| `early_urogenital_28c` | 17 | 17 | 17 | 0 |
| `gonad_temperature` | 83 | 70 | 76 | 7 |

Exactly six gonad columns become eligible because the audited registry now
supplies complete, non-conflicting genotype, temperature, stage, tissue,
library, and specimen mappings:

| Matrix column | Genotype | Temperature | Stage |
|---|---|---:|---|
| `E_82003_22_1_10_Gonad_1` | ZZ | 28 C | S12 |
| `E_82003_22_1_8_Gonad_1` | ZW | 36 C | S12 |
| `E_82003_22_1_9_Gonad_1` | ZW | 36 C | S12 |
| `E_82037_22_1_15_Gonad_1` | ZW | 36 C | S15 |
| `SW_28C2_1aGonad_1` | ZZ | 28 C | S6 |
| `SW_28C2_2cGonad_1` | ZZ | 28 C | S12 |

## Visible unresolved evidence

The builder continues to exclude:

- two time-course columns carrying
  `DEG_ID_inconsistent_with_GROUP`;
- three gonad columns whose matrix identifiers say body while the registry says
  gonad;
- one gonad column with unresolved genotype `F`;
- one organ-culture sample present in the gonad matrix;
- two gonad matrix columns with multiple library mappings, including one
  critical unresolved identity and one mixed-genotype mapping.

These seven gonad questions have been sent to the data owner. No answer is
imputed by the package.

## Reproduction

1. Place `MASTER_pogona_sequencing_SLIM.csv` in the ignored
   `data-raw/pogona/source_metadata/` directory.
2. Confirm its SHA-256 is
   `5a450ef02f148c2fc275b048dca58f51b72fbef0590509450c49a91c8ae147dc`.
3. Ensure the three ignored count and TPM matrix pairs are present.
4. Run `python3 data-raw/pogona/build-metadata.py`.

The builder fails on source-digest drift, count/TPM disagreement, duplicate
matrix columns, unexpected experiment counts, or changed eligibility counts.

**Claim status:** metadata reconciliation and implementation proof only. This
does not establish biological validity, latent-axis recovery, or a supported
sample-size range.
