# Proposed specification — SamplingDesign

**Status:** proposed implementation contract for ADR 0006

## Public interface

```r
cross_sectional()
longitudinal(subject_id, time, time_unit = NULL)
declare_sampling_design(data, design)
```

`cross_sectional()` and `longitudinal()` construct a versioned `SamplingDesign`
S4 object. `declare_sampling_design()` returns the same
`StateTransitionData` with its declared design; it does not mutate caller state.

## Representation

`SamplingDesign` has scalar slots:

- `version`: initially `"1.0.0"`;
- `kind`: `"unspecified"`, `"cross_sectional"`, or `"longitudinal"`;
- `subject_id_col`: zero-or-one `colData` column name;
- `time_col`: zero-or-one `colData` column name;
- `time_unit`: optional scalar description.

`StateTransitionData` gains a versioned `sampling_design` slot. Objects
migrated from the prior schema receive `kind = "unspecified"`.

## Invariants

- A user may declare only `cross_sectional` or `longitudinal`; `unspecified`
  is migration-only.
- Cross-sectional design has no subject/time column references.
- Longitudinal design requires distinct, existing subject and time columns.
  Subject IDs are non-missing; times are numeric, date/time, or ordered;
  at least one subject has distinct repeated times.
- Declaration validates referenced columns. Corruption discovered at a stage
  boundary produces a typed `StageResult` failure.

## Estimator capability

`DynamicsEstimator` gains `supported_sampling_designs(strategy)`.
The structural `estimate_dynamics()` method rejects unspecified or incompatible
designs before calling an implementation hook. `kde_logdensity` declares only
`"cross_sectional"`; a future longitudinal estimator requires its own ADR and
registry strategy.

## Migration and provenance

The implementation performs one schema bump with a registered migration. Every
stage provenance record includes a canonical sampling-design list. Synthetic
constructors declare their known cross-sectional design automatically.

## Required tests

Factory validity; declaration column validation; migration to unspecified;
typed Stage 2 failure for unspecified/incompatible designs; cross-sectional KDE
success; capability dispatch; preservation through projection; and normalized
provenance capture.
