# Implementation plan — issue #54 component gallery repair

> Scheduling remains authoritative in the root [`ROADMAP.md`](../../ROADMAP.md).

**Status:** in progress

## Objective

Repair `plot_components()` so it aligns MAE-level metadata to each selected
assay through the canonical `sampleMap`, visibly renders categorical and
continuous metadata, preserves descriptive component distributions in ordinal
component order, and fails clearly when metadata identity is missing or
ambiguous. The plot remains descriptive and owns no scientific association
score or ranking.

## Pre-agreed public test seams

Issue #54 establishes the public seam, so TDD will observe behavior through:

1. `plot_components()` returned `ggplot` data, labels, scales, and layers;
2. canonical `MultiAssayExperiment::sampleMap()` alignment under deliberately
   different assay-column and MAE `colData` row orders;
3. typed public errors for absent/ambiguous metadata and sample mappings;
4. rendered before/after gallery artifacts for categorical and continuous
   metadata.

Tests will not call private alignment helpers or add a hidden scoring seam.

## Contract

- `colour_by = NULL` keeps unlabelled descriptive densities.
- A non-null `colour_by` is resolved exactly once from MAE-level `colData`.
- Selected-layer assay column names map to primary sample IDs through exactly
  one canonical `sampleMap` row each; row position is never identity.
- Categorical metadata produces discrete colour/fill groups; continuous
  metadata produces a continuous colour gradient while retaining the overall
  descriptive density.
- Missing fields, duplicate field names, missing mappings, and ambiguous
  mappings fail with `landscapeR_validation_error` and actionable messages.
- Components remain in decomposition order (`PC1`, `PC2`, ...). No BC,
  eta-squared, correlation, or private rank is computed.
- Title is exactly `Stage 1 component gallery — layer {n}`.

## Vertical slices

1. Build a deterministic MAE fixture with reordered primary metadata and assay
   columns; red/green canonical categorical alignment.
2. Red/green continuous rendering and scale type.
3. Red/green absent/duplicate field and missing/ambiguous sample-map failures.
4. Remove private BC/separation scoring and assert ordinal facet order, title,
   and descriptive density/rug layers.
5. Update roxygen/current plotting documentation and generate categorical plus
   continuous before/after landing proof.
6. Update roadmap state, run focused/full tests, package check, pkgdown/image and
   policy checks, then perform two-axis review against `origin/main`.
7. Implement every review finding, rerun verification, open the PR, resolve all
   comments, and leave it green and mergeable.

## Claim boundary

Implementation proof only. The gallery displays observations; metadata atlas,
association models, ranking, proposal, stability, and component confirmation
remain #55/#67 and require their accepted statistical-strategy ADR.
