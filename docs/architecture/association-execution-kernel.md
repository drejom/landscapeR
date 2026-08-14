# Normalized association execution kernel

Issue #210 establishes one package-owned execution module for the invariant
parts of metadata interpretation. Cross-sectional and independent destructive
time-course analyses use this module. Repeated-subject migration is tracked
separately in issue #212.

## Ownership boundary

| Design adapter owns | Execution kernel owns |
| --- | --- |
| Cohort construction and exclusions | Validated strategy resolution |
| Biological estimand and model fit | Work-item and component traversal |
| Exchangeability and resampling indices | Future result and failure accounting |
| Scientific diagnostics and display records | Normalized association and observation rows |
| Design-specific permutation behavior | Multiplicity, cohort expansion, and atlas assembly |
| Typed reasons that evidence is not estimable | Unchanged propagation of typed abstention |

The kernel cannot select a component, alter an estimand, substitute a fallback
model, reinterpret exchangeability, or create a scientific threshold. Those
boundaries remain governed by ADR 0020 and the design-specific strategies.

## Internal adapter contract

An execution adapter declares an identifier, one sampling design, and three
callbacks:

1. `prepare()` returns finite component coordinates, unique labels, scientific
   work items, validated strategy contracts, adapter state, and exclusions.
2. `execute_component()` fits one declared work item on one component and
   returns association rows, observation rows, execution records, scientific
   records, and display records.
3. `finalize()` maps normalized results and design provenance to an atlas
   blueprint. The kernel validates the blueprint and constructs the S4 atlas.

Malformed callback output raises `association_execution_error`, which also
inherits from `landscapeR_validation_error`. Incidental dependency errors are
translated at this boundary. An `AssociationAbstention` returned during
preparation, component execution, or finalization is returned unchanged.

## Method-author path

Authors adding an estimator to an existing supported design do not write a
kernel adapter. They register an `AssociationStrategy` and implement the narrow
scientific methods documented in
[`docs/agents/association-strategy-authoring.md`](../agents/association-strategy-authoring.md).
The package-owned design adapter supplies the surrounding execution mechanics.

## Evidence of behavior preservation

`tests/testthat/test-association-execution-kernel.R` freezes atlas and evidence
digests for successful and partial cross-sectional and independent-time-course
analyses. It also freezes the non-identifiable time-course abstention. The
landing proof in `.github/landing-proof/issue-210/` renders the shared workflow
and records those identities.
