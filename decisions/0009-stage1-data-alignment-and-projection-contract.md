# 0009 — Stage 1 data alignment and projection contract

**Stage:** 1 / cross-cutting
**Status:** accepted
**Date:** 2026-07-12

## Context

Stage 1 must support genuine multi-omic inputs: omic layers have different
feature spaces while referring to matched biological observations. The current
implementation assumes a common feature dimension, trusts assay column order,
and projects a secondary cohort by raw feature position after independently
centring it. Those assumptions conflict with the intended
`MultiAssayExperiment` model and make discovery/confirmation claims unsafe.

Real cohorts can also contain failed measurements in one omic layer. Missing
blocks must not be interpolated or zero-filled merely to preserve a rectangular
input.

## Options considered

| Option | Key property | Disqualifier or concern |
|---|---|---|
| Require equal feature counts and aligned assay order | Simple implementation | Invalid for transcriptome/pathology/genotype inputs; silently misaligns samples. |
| Impute or zero-fill missing omic blocks | Preserves all observations | Creates artificial cross-layer structure and unsupported certainty. |
| Use MAE sample mapping, complete paired fitting, layer-specific feature spaces, and explicit projection feature IDs | Matches scientific data structure | Requires Stage 1 result and projection redesign. |
| Adopt a missing-block factorisation now | Could use incomplete observations jointly | No selected method or Stage 0 missingness evidence. |

## Criteria

- Different omic layers may have different feature sets and feature counts.
- Shared Stage 1 structure is defined on correctly matched biological
  observations, never assay-column order.
- Stage 1 fitting uses the complete paired cohort; incomplete observations are
  not jointly fitted, interpolated, or zero-filled.
- Projection uses stable feature identity and the discovery cohort's fitted
  preprocessing reference.
- All exclusions, mappings, and preprocessing references are provenance-recorded.

## Evidence

`MultiAssayExperiment` provides `sampleMap` and `colData` for canonical
biological-observation mapping, while each `SummarizedExperiment` retains
per-assay `rowData` feature annotation. It does not automatically harmonise
features between cohorts. The current code does not yet use these guarantees.

## Decision

**Chosen:** use `MultiAssayExperiment` sample mapping to construct and validate
the complete paired cohort for Stage 1. Retain layer-specific feature loadings
and represent shared structure in matched sample space, so equal feature
dimensions are never required.

For projection, each projected assay must expose a canonical, unique feature-ID
field in `rowData`; the primary and secondary cohort are matched under a
declared harmonisation rule. Projection initially rejects missing required
features rather than imputing them and applies discovery-cohort fitted
centring/scaling parameters rather than independently recentering the
secondary cohort.

Technical-replicate resolution remains assay-specific upstream preprocessing.
Projection-only handling of incomplete biological observations is deferred to
Issue #22 after Stage 0 missingness controls.

## Consequences

- Stage 1 and `DecompositionResult` need a redesign before multi-omic
  end-to-end claims.
- Stage 0 controls must include heterogeneous feature spaces, complete-case
  exclusions, missingness patterns, and projection recovery.
- `project_into()` requires typed failures and tests for feature-ID mismatch,
  sample-map ambiguity, and preprocessing-reference mismatch.
- Existing equal-dimension synthetic examples remain useful only as a special
  case, not the contract.

## Review trigger

Revisit if a validated missing-block multi-view estimator becomes necessary, or
if a real application requires a feature-harmonisation policy more complex than
one-to-one canonical IDs.
