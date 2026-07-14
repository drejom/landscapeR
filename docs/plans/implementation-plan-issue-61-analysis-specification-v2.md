# Implementation plan — issue #61 AnalysisSpecification v2

> **Historical implementation record.** Status and sequencing in this file
> describe its originating work and are superseded for current scheduling by
> the root [`ROADMAP.md`](../../ROADMAP.md).

**Status:** complete; two-axis code review completed before PR

## Objective

Replace the lossy v1 target/component XOR with a versioned lifecycle that keeps
complete target intent through proposal and confirmation, and provide an
explicit no-fabrication migration for v1 objects/artifacts.

## Pre-agreed public test seams

Issue #61 already names the public seams, so TDD will observe behavior through:

1. `analysis_specification()` for draft, proposal, and confirmed construction;
2. `canonical_digest()` and pipeline provenance for complete deterministic
   identity;
3. `migrate_analysis_specification()` for real serialized v1 artifacts;
4. `run_pipeline()` for metadata/value validation, lifecycle eligibility,
   selected-component bounds, and Stage 2 parameter propagation.

Tests will not assert private helper structure.

## Contract to implement

- Schema version `2.0.0` and `selected_component`; no v2
  `manual_component` slot or constructor argument.
- Complete target declaration for every v2 object:
  - binary: `reference_level` and `comparison_level`;
  - ordered: `ordered_levels`;
  - continuous: `continuous_direction` (`increasing` or `decreasing`).
- Lifecycle invariants:
  - `draft`: target only;
  - `proposal`: target plus proposal digest;
  - `confirmed`: target, proposal digest, selected component,
    accepted/overridden decision, and non-empty analyst rationale.
- Claim intent remains declarative and is included in identity/provenance.
- Explicit v1 migration preserves all recoverable fields and source digest;
  missing target direction, target identity, or confirmation provenance must be
  supplied explicitly or migration fails. No fabricated target and no silent
  component discard.

## Vertical slices

1. Create serialized v1 fixtures before changing the class.
2. Red/green v2 target declaration and draft validity.
3. Red/green proposal and confirmed lifecycle validity.
4. Red/green digest/provenance coverage for every new field.
5. Red/green explicit v1 target-only and manual-only migration, including hard
   no-fallback failures.
6. Red/green pipeline boundary validation and Stage 2 selected-component use.
7. Migrate package-owned synthetic calibration and test configurations.
8. Update current specification docs, roxygen examples, README/vignette where
   needed, and PR landing proof.
9. Anticipate merge in `ROADMAP.md`: #61 becomes `complete on merge` and #53 is
   the sole next task.
10. Run focused/full tests, package check, pkgdown/image checks, repository
    policy checks, completion audit, then `/code-review` before opening the PR.

## Visual landing proof

The PR will include:

- a before/after v1 → v2 migration table, including required explicit inputs;
- a representative draft → proposal → confirmed lifecycle table showing the
  unchanged target declaration digest/content;
- claim status: schema/API implementation proof only; no scientific acceptance
  claim.

## Completion verification

- 523 R assertions passed.
- 35 repository policy/checker tests passed.
- ADR coverage, registry compliance, roadmap/live-issue integrity, and diff
  whitespace checks passed.
- pkgdown rebuilt successfully; both article image audits passed and the v2
  lifecycle table rendered in the development log.
- Full package build/check completed with only the existing local
  `MultiAssayExperiment` R-version warning and benchmark-path NOTE.

## Pre-PR two-axis code review

`/code-review` was pinned to `origin/main...HEAD` with issue #61 and ADR 0008 as
the specification sources. The runtime had exhausted its subagent spawn quota,
so the Standards and Spec axes were completed independently in the parent as the
required fallback rather than omitted.

- **Standards:** one implementation-coupled test reached through the private
  `.analysis_spec_provenance()` helper. It was changed to inspect provenance
  through the public `run_pipeline()` result seam. No unresolved standards or
  smell findings remain.
- **Spec:** no missing, incorrect, or out-of-scope behavior found after mapping
  every issue #61 requirement to constructor, migration fixture, boundary,
  provenance, documentation, and landing-proof artifacts.

## Pull-request review follow-up

All five automated review comments were addressed before merge readiness:

- non-finite selected components now fail with the intended constructor error,
  covered by a regression test;
- `anyDuplicated()` conditions now compare explicitly with `0L`;
- test SHA fixtures use `strrep()` consistently;
- the synthetic proposal digest no longer includes the later selected-component
  decision; and
- proposal-stage tables say the digest is first **present**, then **retained** at
  confirmation.
