# Proposed specification — AnalysisSpecification

**Status:** proposed implementation contract for ADR 0008

## Public interface

```r
analysis_specification(
  id,
  target_field = NULL,
  manual_component = NULL,
  nuisance_fields = character(),
  orientation_anchor = NULL,
  claim_intent = c("exploratory", "primary_confirmatory")
)
```

`PipelineConfig` gains one versioned `analysis` specification. It expresses
intent for exactly one target-axis run; it is not attached to the dataset,
because the same data may support separate biological questions.

## Representation

`AnalysisSpecification` has:

- `version`: initially `"1.0.0"`;
- `id`: non-empty run identity;
- `target_field`: zero-or-one `colData` field for a component proposal;
- `manual_component`: zero-or-one positive integer component choice;
- `nuisance_fields`: unique metadata field names;
- `orientation_anchor`: optional numeric metadata field;
- `claim_intent`: `"exploratory"` or `"primary_confirmatory"`.

## Invariants

- Exactly one of `target_field` or `manual_component` is supplied.
- Target, nuisance, and orientation names are distinct; nuisance names are
  unique.
- A target field produces a reproducible **proposal only**. It may not silently
  select a component. A Stage 2 run needs an explicit manual component choice
  after review; provenance links the accepted choice to its proposal.
- A manual component is checked against the available Stage 1 components.
- The orientation anchor is numeric, non-degenerate, and records convention
  only. It is not evidence of dynamics.
- `primary_confirmatory` declares intent, not eligibility. Applicability,
  sampling-design, concordance, stability, and Stage 0 gates determine the
  actual claim status.

## Boundary and provenance

Class validity checks shape and internal consistency. Pipeline/stage boundaries
check `colData` existence and required values. Missing required design metadata
is recorded as an analysis-cohort exclusion; diagnostic metadata remains
available-case only. Every successful stage records the canonical specification
and digest in provenance.

## Required tests

Constructor defaults; mutually exclusive target/manual choices; invalid roles,
claim intent, and component indexes; metadata/type validation; no silent target
selection; orientation validation; manual-component bounds; and canonical
provenance digest capture.
