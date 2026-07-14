# 0008 — Analysis specification for one target-axis run

**Stage:** cross-cutting / 1 / 2
**Status:** accepted
**Date:** 2026-07-12

## Context

A reproducible real-data analysis now requires more than an algorithm choice:
it has one target biological variable, named nuisance variables, an optional
orientation anchor, and confirmatory or exploratory claim status. These are not
intrinsic facts about a dataset: the same `StateTransitionData` may support
separate developmental, sex-determination, and treatment-response analyses.

Adding unrelated declarations to data objects would make the same cohort carry
competing scientific intentions. Conversely, a separate full study-planning
hierarchy is premature: no caller yet needs recruitment, power, or protocol
management.

## Options considered

| Option | Key property | Disqualifier or concern |
|---|---|---|
| Separate user-facing declarations for each concern | Incremental | Shallow, fragmented interface; easy to omit or mix declarations. |
| Store analysis intent on `StateTransitionData` | Travels with data | Incorrectly treats an analysis question as a data-collection fact. |
| Add a compact versioned analysis specification to `PipelineConfig` | One coherent declaration per run | Extends the configuration contract and needs validation. |
| Introduce a full `AnalysisPlan` hierarchy | Broad future flexibility | Premature without callers for the extra scope. |

## Criteria

- One target biological axis per reproducible run.
- The same dataset may support multiple distinct, named runs without mutation.
- Selection, nuisance, orientation, and claim status are validated and recorded
  together in provenance.
- The interface remains small enough for ordinary end users.
- Scientific intent is separate from intrinsic sampling design.

## Evidence

This decision follows the accepted policies for component selection, metadata
roles, orientation, discovery/confirmation, and multiplicity. No algorithm or
Stage 0 result selects this configuration shape.

## Decision

**Chosen:** add one compact, versioned analysis specification to
`PipelineConfig`.

The specification defines exactly one target biological variable or manual
component choice, named nuisance variables, an optional orientation anchor, and
whether the run is the study's primary confirmatory analysis or exploratory.
The `StateTransitionData` container retains only intrinsic facts, including the
sampling-design declaration in ADR 0006. A run's complete analysis
specification is persisted in provenance.

**Amendment (2026-07-13): target declarations carry their own direction.** A
binary target declares neutral `reference_level` and `comparison_level` terms;
an ordered target declares `ordered_levels`; and a continuous target declares
an increasing or decreasing direction. The target's declared contrast/order is
the default axis-orientation rule. The term `positive_level` is prohibited
because it conflates coefficient sign, disease positivity, and value judgement.
A separate orientation anchor is needed only when the target declaration does
not supply a scientifically meaningful direction. Axis direction is fixed
before Stage 2 and is never chosen from fitted landscape topology.

**Amendment (2026-07-13): selection resolves rather than replaces the target.**
The original mutual exclusion between `target_field` and `manual_component` is
superseded. A draft specification carries the complete target declaration but
no selected component. Confirmation retains that target and adds
`selected_component`, the component index in the frozen reference basis. The
term `manual_component` is removed: manual acceptance or override is decision
provenance, not a property of the component. The confirmed specification also
records the proposal digest, whether the recommendation was accepted or
overridden, and the analyst rationale. A versioned migration is required; no
legacy/null fallback may silently discard target intent.

**Amendment (2026-07-13): guard claims, not scientific function calls.** The
curated runner and evidence assembler use the specification to determine claim
eligibility, but low-level pure functions remain public and composable. An
analyst may inspect any component, override a proposal, run an estimator ad hoc,
or construct a custom pipeline. Such work returns ordinary structured results
with provenance; it is not blocked merely because it departs from the curated
path. A post-inspection override or incompletely specified custom run is labelled
exploratory by standard evidence tooling and cannot be silently promoted to
confirmatory. Predeclared override rules may remain confirmatory-eligible when
recorded before inspection and when all other gates pass.

## Consequences

- `PipelineConfig` validation grows beyond dataset and strategy identifiers.
- Multiple target questions require multiple named configurations, preventing
  silent search across targets.
- The package must expose a compact constructor or helper rather than requiring
  users to compose S4 internals.
- Confirmatory claims require the discovery/confirmation and applicability-gate
  policies defined elsewhere.

## Review trigger

Revisit if two concrete callers need study-level information beyond this scope,
such as power, recruitment, preregistration documents, or multiple linked
endpoints; then consider a separate `AnalysisPlan` module.
