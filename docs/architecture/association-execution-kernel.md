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
| Design-specific permutation behavior | Multiplicity, cohort expansion, and typed atlas assembly |
| Typed reasons that evidence is not estimable | Unchanged propagation of typed abstention |

The kernel cannot select a component, alter an estimand, substitute a fallback
model, reinterpret exchangeability, or create a scientific threshold. Those
boundaries remain governed by ADR 0020 and the design-specific strategies.

## Internal adapter contract

An execution adapter declares an identifier, one sampling design, and two
callbacks:

1. `prepare()` returns finite component coordinates, unique labels, scientific
   work items, validated strategy contracts, adapter state, and exclusions.
2. `execute_component()` fits one declared work item on one component and
   returns association rows, observation rows, execution records, scientific
   records, and display records.

After execution, the design module supplies its scientific provenance and
display evidence in an atlas blueprint. The kernel validates that blueprint
and constructs the S4 atlas. This keeps scientific meaning in the design
module without duplicating S4 assembly or leaking incidental construction
errors.

Malformed callback output raises `association_execution_error`, which also
inherits from `landscapeR_validation_error`. Incidental dependency errors are
translated at this boundary. An `AssociationAbstention` returned during
preparation or component execution is returned unchanged.

## Method-author path

Authors adding an estimator to an existing supported design do not write a
kernel adapter. They register an `AssociationStrategy` and implement the narrow
scientific methods documented in
[`docs/agents/association-strategy-authoring.md`](../agents/association-strategy-authoring.md).
The package-owned design adapter supplies the surrounding execution mechanics.

## Evidence of behavior preservation

`tests/testthat/test-association-execution-kernel.R` freezes exact atlas digests
for successful and partial rank-only cross-sectional analyses. Fitted
independent-time-course analyses use a portable scientific fingerprint that
retains normalized evidence, the declared model engine, fitted scientific
summaries, RNG identity, and the scientific provenance tree. It excludes the
runtime model-engine version and raw byte digests whose normalized underlying
evidence or repetition records are already retained. The test also freezes the
non-identifiable time-course abstention and proves that changes to the
specification, model formula, model engine, resampling plan, fitted model,
repetition values, or association evidence alter the fingerprint. The landing
proof uses five-decimal quantization: six decimals failed the supported
macOS/Linux fixture comparison, while changes of `1e-4` remain detectable.
The landing proof in
`.github/landing-proof/issue-210/` renders the shared workflow and records
those identities.
