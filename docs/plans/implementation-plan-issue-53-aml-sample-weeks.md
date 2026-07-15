# Implementation plan — issue #53 AML source weeks and cohort identity

> Scheduling remains authoritative in the root [`ROADMAP.md`](../../ROADMAP.md).

**Status:** implementation complete; two-axis review findings fixed; PR pending

## Objective

Correct the reversed GSE133642 2016/2018 prepared-layer assignments and carry
the authoritative public `sample_weeks` values into both layers without deriving
time or inventing endpoint semantics. Together the matrices remain a real
biological validation dataset for landscapeR; their source-paper roles remain
explicit and distinct.

## Pre-agreed test seams

The issue and source-lineage audit establish these observable seams:

1. the committed, privacy-safe GSE133642 sample-time mapping artifact;
2. the data-preparation mapping function used by `data-raw/load-aml-cml.R`;
3. the generated `StateTransitionData` schema, layer assignment, declared
   `SamplingDesign`, and data-source provenance;
4. the prepared-data documentation and PR landing-proof tables.

Tests will not require network access or reconstruct expected weeks from dates
or categorical labels.

## Contract

- `mrna_primary_2018`: 132 observations from source cohort
  `AML.mRNA.2018.all_samples`, the source-paper training/state-space cohort.
- `mrna_supp_2016`: 101 observations from source cohort `AML.mRNA.2016`, the
  source-paper validation cohort retained as landscapeR's hostile projection
  stress test after excluding the separate 15-observation `WK*` arm.
- Every retained observation maps one-to-one by authoritative `library_id` and
  receives the source numeric `sample_weeks` value unchanged.
- The combined container declares `longitudinal("mouse_id", "sample_weeks",
  "weeks")`.
- Existing categorical labels remain inert metadata. No endpoint/event field,
  inference, or general disease-specific contract is added.
- Provenance records the immutable source revision, source checksum, file,
  column, units, join key, and extraction procedure.

## Vertical slices

1. Red/green the source mapping artifact integrity and corrected layer counts.
2. Red/green exact mapping, unmatched/duplicate rejection, and literal decimal
   values including all six source `L` observations.
3. Switch the raw matrices and metadata parsers to their correct prepared
   layers; attach exact weeks through the validated mapping seam.
4. Declare the minimal longitudinal sampling design and record source/cohort
   provenance.
5. Regenerate and audit the local prepared object: 233 observations, 30 mice,
   no missing weeks, strict within-mouse ordering, and corrected 132/101 roles.
6. Update prepared-data documentation, source-study/package-validation wording,
   roadmap state, and privacy-safe landing proof.
7. Run focused/full tests, package check, pkgdown/policy checks, and an explicit
   completion audit.
8. Run the two-axis `/code-review` against `origin/main`, implement all findings,
   rerun verification, then open the PR with immutable landing-proof links.

## Claim boundary

This is data-lineage and machinery-validation work. It makes no biological,
endpoint, longitudinal-dynamics, or strategy-acceptance claim.

## Pre-PR two-axis code review

The review was pinned to `origin/main` at
`2e6190010b136e4cfe3c443493f66225f372abe0` and issue #53. The session-wide
subagent spawn quota was already exhausted, so the Standards and Spec axes were
performed as separate direct passes rather than omitted.

**Standards findings fixed:**

1. Added `data-raw/build-gse133642-sample-weeks.R` so the packaged mapping is
   reproducible from the immutable source and fails on SHA-256 drift.
2. Extracted the data-preparation mapping seam to the non-exported
   `inst/scripts/gse133642-metadata.R`, shared by the loader and tests rather
   than hiding validation in the monolithic loader.

**Spec findings fixed:**

1. Added behavioral tests proving duplicate source keys, unmatched expression
   observations, and mouse-identity drift fail closed.
2. Added `data-raw/check-gse133642-prepared.R` to reproducibly audit the local
   generated objects, full provenance, minimal SamplingDesign, and corrected
   multi-modal consequence instead of relying on an ad hoc command.

No findings remain on either axis after the fixes.

## Pull-request review follow-up

All five automated review comments were implemented before merge readiness:

- tests prefer the source-tree mapping helper and fall back to the installed
  package path, avoiding stale installed code during `devtools::test()`;
- downloaded source metadata is removed with function-scoped `on.exit()`;
- gzip header connections are explicitly opened and closed;
- the packaged mapping is ordered by layer, mouse, and authoritative weeks; and
- the loader orders both expression matrices and metadata chronologically, while
  tests and the generated-object audit now check `diff(weeks) > 0` in stored
  order rather than sorting before the assertion.
