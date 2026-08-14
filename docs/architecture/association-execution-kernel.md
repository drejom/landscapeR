# Normalized association execution kernel

Issue #210 establishes one package-owned execution module for the invariant
parts of metadata interpretation. Cross-sectional, independent destructive
time-course, and repeated-subject time-course analyses use this module.

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

For repeated-subject analyses, the design adapter continues to own complete
subject trajectories, the random-intercept and random-slope model, singular and
nonconvergent diagnostics, condition-stratified trajectory resampling, and
between-subject assignment permutation. The kernel sees completed scientific
rows and records only. It cannot split a subject trajectory or weaken the
declared model.

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
independent-time-course analyses use a complete portable payload comparison that
retains normalized evidence, the declared model engine, fitted scientific
summaries, RNG identity, and the scientific provenance tree. It excludes the
runtime model-engine version and raw byte digests whose normalized underlying
evidence or repetition records are already retained. The test also freezes the
non-identifiable time-course abstention and proves that changes to the
specification, model formula, model engine, resampling plan, fitted model,
repetition values, or association evidence fail the comparison. Nonnumeric
values and structure match exactly; floating-point values use an absolute
tolerance of `1e-6`, and changes of `1e-4` remain detectable.
The fitted reference payloads and their manifest are generated from the pinned
pre-migration revision by
`tests/testthat/fixtures/generate-association-execution-reference.R`;
changing that revision is an explicit scientific-baseline change, not routine
proof maintenance. The generator is included in built-package tests so the
manifest's code identity remains verifiable during `R CMD check`.
The landing proof in
`.github/landing-proof/issue-210/` renders the shared workflow and records
those identities.

`tests/testthat/test-repeated-association-execution-kernel.R` records the
pre-migration repeated-design estimates, eligibility, resampling identity,
failure accounting, evidence dimensions, and rank recurrence. It also proves
that identical seeds produce identical scientific results under sequential and
multisession future backends. The existing repeated-time-course suites retain
the singular, nonconvergent, partial, invalid-assignment, permutation, dropout,
and typed-abstention boundaries. The landing proof in
`.github/landing-proof/issue-212/` shows an estimable repeated trajectory and
the corresponding visible abstention when the random-slope model is singular.
