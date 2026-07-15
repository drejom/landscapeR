# Issue #54 visual landing proof

**Claim status:** plotting implementation proof only. These synthetic component
distributions do not select, rank, confirm, or validate a biological axis.

## Before: metadata silently absent and panels privately ranked

![Before repair: uncoloured galleries, duplicated title, and BC-sorted panels](before.png)

The deterministic fixture deliberately places assay columns and MAE-level
metadata rows in different orders. Before the repair, `plot_components()` looked
only in per-experiment `colData`, so the requested `condition` colour vanished.
It also displayed the duplicated title and reordered PC2 ahead of PC1 using a
private bimodality score.

## After: categorical metadata

![After repair: categorical condition groups aligned through sampleMap](after-categorical.png)

The categorical gallery resolves each assay column through `sampleMap` to its
MAE primary observation. CM and CTL distributions and rugs are visibly distinct,
while panels remain PC1, PC2, PC3.

## After: continuous metadata

![After repair: continuous sample weeks shown as a gradient rug](after-continuous.png)

Continuous metadata use a gradient rug beneath the unconditioned descriptive
density. This keeps the observation distribution visible without turning the
plot into an association model.

## Observable contract

| Behavior | Before | After |
|---|---|---|
| Metadata source | Per-experiment `colData`; MAE metadata silently missed | MAE-level `colData` aligned through canonical `sampleMap` |
| Categorical colour | Absent | Discrete grouped densities and rugs |
| Continuous colour | Unsupported by the discrete scale | Continuous gradient rug with overall density retained |
| Panel order | Private BC ranking (`PC2`, `PC1`, `PC3` in the fixture) | Decomposition order (`PC1`, `PC2`, `PC3`) |
| Title | `Component component plots -- layer 1` | `Stage 1 component gallery — layer 1` |
| Missing/ambiguous identity | Silent colour removal | Typed `landscapeR_validation_error` |
| Scientific score/rank | BC plus eta-squared/correlation labels | None; atlas/proposal work remains #55 |

## Canonical alignment check

The fixture uses 24 synthetic primary observations and gives assay columns,
`sampleMap` rows, and MAE `colData` rows three deliberately different
permutations. The first six assay columns demonstrate that no positional join
can recover the metadata:

| Assay position | Assay column / primary | `sampleMap` row | MAE `colData` row | Condition | Weeks |
|---:|---|---:|---:|---|---:|
| 1 | `rna_07` / `p07` | 24 | 14 | CTL | 9.0 |
| 2 | `rna_02` / `p02` | 23 | 4 | CM | 1.5 |
| 3 | `rna_19` / `p19` | 22 | 11 | CTL | 27.0 |
| 4 | `rna_04` / `p04` | 21 | 8 | CM | 4.5 |
| 5 | `rna_23` / `p23` | 20 | 3 | CTL | 33.0 |
| 6 | `rna_06` / `p06` | 19 | 12 | CM | 7.5 |

Tests independently follow assay column → map row → primary metadata identity
and recover all 24 categorical and continuous values exactly. PC2 was planted
from the primary condition, so its clean CM/CTL separation in the after render
is also an inspectable consequence of correct canonical alignment.

## Reproduction

```sh
Rscript scripts/render-issue-54-landing-proof.R
Rscript -e 'devtools::test(filter = "stage1-plots")'
```

`before.png` is the archival render from `origin/main` before the repair using
the same deterministic fixture. The render script regenerates both current
after images.
