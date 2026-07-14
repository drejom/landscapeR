# AnalysisSpecification v2

**Status:** implemented contract for ADR 0008

## Purpose

`AnalysisSpecification` carries one complete target hypothesis through
component proposal and human confirmation. It belongs to `PipelineConfig`, not
to `StateTransitionData`, because the same data may support multiple distinct
questions.

Selection resolves the target; it never replaces it.

## Public constructor

```r
analysis_specification(
  id,
  target_field,
  target_type,
  reference_level = NULL,
  comparison_level = NULL,
  ordered_levels = character(),
  continuous_direction = NULL,
  lifecycle = "draft",
  selected_component = NULL,
  proposal_digest = NULL,
  proposal_decision = NULL,
  analyst_rationale = NULL,
  nuisance_fields = character(),
  orientation_anchor = NULL,
  claim_intent = c("exploratory", "primary_confirmatory")
)
```

`migration_source_digest` is populated only by
`migrate_analysis_specification()`; the public constructor does not accept it.

## Complete target declaration

Every v2 object has one `target_field` and one `target_type`:

| Target type | Required direction | Prohibited alternatives |
|---|---|---|
| `binary` | distinct `reference_level` and `comparison_level` | `ordered_levels`, `continuous_direction` |
| `ordered` | at least two unique `ordered_levels` in scientific order | binary levels, `continuous_direction` |
| `continuous` | `continuous_direction = "increasing"` or `"decreasing"` | discrete levels |

Neutral reference/comparison terms are deliberate. `positive_level` is not part
of the interface because it conflates coefficient sign, disease positivity, and
value judgement.

At the pipeline boundary, declared metadata must exist. Binary and ordered
cohorts must contain exactly their declared non-missing values. Continuous
targets must be finite numeric values with non-zero variance.

## Lifecycle

| Lifecycle | Target declaration | Proposal digest | Selected component | Decision + rationale |
|---|---:|---:|---:|---:|
| `draft` | required | absent | absent | absent |
| `proposal` | retained | required | absent | absent |
| `confirmed` | retained | retained | required | required |

A proposal digest identifies the separately inspectable ranked
`ComponentProposal` that #55 will implement. The specification does not embed a
second ranking implementation.

`proposal_decision` is `accepted` or `overridden`. Both require non-empty analyst
rationale. `selected_component` is the component index in the frozen reference
basis and is checked against the fitted Stage 1 result before Stage 2.

Real-data confirmation is human-only. Synthetic truth may support automated
assertions. `claim_intent = "primary_confirmatory"` declares intent but cannot
bypass applicability, stability, sampling-design, or Stage 0 gates.

## Examples

```r
# Draft: complete target, no selected component
draft <- analysis_specification(
  id = "aml-condition-over-time",
  target_field = "condition",
  target_type = "binary",
  reference_level = "CTL",
  comparison_level = "CM",
  nuisance_fields = c("weeks", "batch"),
  claim_intent = "exploratory"
)

# Proposal: target is unchanged; only the proposal identity is added
proposal <- analysis_specification(
  id = "aml-condition-over-time",
  target_field = "condition",
  target_type = "binary",
  reference_level = "CTL",
  comparison_level = "CM",
  lifecycle = "proposal",
  proposal_digest = strrep("a", 64),
  nuisance_fields = c("weeks", "batch")
)

# Confirmed: target remains and decision provenance is explicit
confirmed <- analysis_specification(
  id = "aml-condition-over-time",
  target_field = "condition",
  target_type = "binary",
  reference_level = "CTL",
  comparison_level = "CM",
  lifecycle = "confirmed",
  selected_component = 2L,
  proposal_digest = strrep("a", 64),
  proposal_decision = "accepted",
  analyst_rationale = "Accepted the predeclared top-ranked target axis.",
  nuisance_fields = c("weeks", "batch")
)
```

## Explicit v1 migration

Use `migrate_analysis_specification()` on an in-memory or deserialized v1 object.
Migration records the exact v1 canonical payload digest in
`migration_source_digest`.

A target-only v1 object knows its field but not contrast/order/direction, so the
missing declaration is mandatory. With no proposal digest it becomes a draft;
if the caller supplies the digest of an existing ranked proposal it becomes a
proposal:

```r
v2_draft <- migrate_analysis_specification(
  legacy_target_spec,
  target_type = "binary",
  reference_level = "CTL",
  comparison_level = "CM"
)
```

A manual-component-only v1 object knows neither the target nor the proposal
history. Migration therefore requires every missing field and preserves the old
component as `selected_component`:

```r
v2_confirmed <- migrate_analysis_specification(
  legacy_component_spec,
  target_field = "condition",
  target_type = "binary",
  reference_level = "CTL",
  comparison_level = "CM",
  proposal_digest = proposal_digest,
  proposal_decision = "overridden",
  analyst_rationale = "Reconciled the legacy choice with the restored target."
)
```

Without those explicit inputs migration fails. There is no null/legacy fallback
that invents target intent or silently discards a selected component.

## Identity and provenance

`canonical_digest()` covers the schema version, lifecycle, complete target
declaration, selected component, proposal decision, nuisance/orientation fields,
claim intent, and migration source digest. Every pipeline stage records that
canonical payload plus its digest in provenance.
