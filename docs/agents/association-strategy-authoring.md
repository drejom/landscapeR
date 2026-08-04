# Association strategy authoring

`AssociationStrategy` is the only extension seam for Stage 1 metadata
interpretation. A method author registers one adapter and implements scientific
behavior; landscapeR retains authority over evidence storage, provenance,
future execution, failure accounting, atlas construction, and proposal rules.

## Required adapter surface

An adapter subclasses `AssociationStrategy` and implements:

- `association_applicable()` to identify its declared design and target;
- `association_contract()` to declare supported designs and targets, its
  estimand, cohort, diagnostic, abstention, refit, and evidence policies;
- `associate_component()` to return one narrow scientific fit result; and
- `association_strategy_id()` to provide stable provenance.

The inherited `prepare_association()` and `refit_association()` methods supply
available-case cohort construction and index-based refitting. Override them
only when the biological sampling unit requires different behavior, as the
independent and repeated time-course strategies do. Overrides return ordinary
preparation and fit results; they never construct evidence tables or S4 result
objects.

```mermaid
flowchart LR
    A[Registered strategy] --> B[Validated contract]
    B --> C[Strategy-owned cohort]
    C --> D[Component fit]
    D --> E[Package-owned future refits]
    E --> F[Normalized evidence boundary]
    F --> G[Atlas or typed abstention]
```

## Contract rules

The contract is a named list with exactly these fields: `version`,
`sampling_designs`, `target_types`, `estimand`, `cohort_policy`,
`diagnostic_prefix`, `abstention_statuses`, `refit_policy`, and
`evidence_version`. Every field is validated before the adapter is invoked.
Malformed or ambiguous registrations fail at `associate_metadata()`; they do
not fall through to another estimator.

Strategy contracts are copied into atlas provenance. This makes the selected
estimand, cohort and refit policies auditable without exposing private engine
objects. Registered strategies may not change multiplicity, exchangeability,
component ranking, acceptance, or human-confirmation rules.

## Conformance

Start with the narrow fixture in
`tests/testthat/test-association-strategy-authoring.R`. It demonstrates a new
target type that reaches a complete `MetadataAssociationAtlas` through
`associate_metadata()` without editing central dispatch, plus a malformed
adapter rejected at the same seam. Add design-specific tests for cohort
exclusion, typed abstention, deterministic refitting, serialization and
provenance before proposing a production strategy.

Bayesian, GEE, nonlinear and survival engines can use this seam in future, but
each requires a separate scientific decision and implementation. Registration
alone does not expand landscapeR's accepted scientific scope.
