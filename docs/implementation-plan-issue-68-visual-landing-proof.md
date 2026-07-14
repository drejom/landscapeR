# Implementation plan — issue #68 PR-co-located visual landing proof

## Objective

Make visual landing proof a mandatory, reviewable completion surface for
qualifying landscapeR changes without confusing implementation proof, current
user documentation, or immutable scientific evidence.

## Governing decisions

- ADR 0017: observation before interpretation.
- ADR 0016: K=1 SVD is calibration/development work until the frozen Stage 0
  acceptance ladder passes.
- Issue #68 is the specification and Definition of Done.

## Confirmed test seams

The conversation and issue #68 establish one primary policy seam:

1. **PR-policy checker CLI** — invoke the checker exactly as CI does against a
   PR body and a Git diff. Assert exit status and user-facing diagnostics.

The existing pkgdown site build is the render-integrity seam. It remains
separate from policy classification and does not justify a second policy API.

## Vertical slices

1. **Mandatory classification**
   - Red: a PR with neither/both proof classifications passes today.
   - Green: require exactly one of proof-required or exempt.
2. **Substantive exemption**
   - Red: `N/A` passes today.
   - Green: require a valid exemption category and non-placeholder rationale.
3. **Required proof packet**
   - Red: a vignette change plus any nonempty line passes today.
   - Green: require before/after or new-capability proof, cold-reader
     interpretation, reproduction instructions, and claim status.
4. **Current-documentation declaration**
   - Red: a public workflow can change while current documentation remains
     stale.
   - Green: require either a changed current-documentation surface or a
     substantive explanation that current documentation is unaffected.
5. **Repository policy wiring**
   - Run checker tests and the checker in CI on every PR.
   - Retain pkgdown build as render verification.
6. **Decision and workflow documentation**
   - Amend ADR 0017, ADR template, project instructions, issue-tracker guidance,
     and PR template with one consistent rule.
7. **#50 reference proof**
   - Replace the obsolete duplicated-omic-layer workaround in current docs.
   - Show direct registered SVD and a K=1 quasi-potential/calibration result.
   - Label the output calibration-only and non-evidentiary.
   - Put the full transition proof in the PR; keep the development log concise.
8. **Open-issue backfill**
   - Add required proof to #5, #24, #41, #49–#53, #57, #60, #61, #66, #67.
   - Strengthen partial proof in #22, #54, #55, #59.
   - Add explicit implementation-deferred exemptions to #56, #58, #62–#65.
9. **PR and merge policy**
   - Preserve the six #50 commits on this feature branch.
   - Open a PR targeting `main` that links #50 and #68 and carries the first
     complete proof packet.
   - Enable branch protection only after required checks are known and the PR
     path is viable.

## Visual landing proof for this change

This issue changes a developer workflow and the public K=1 workflow.

- **Before:** the old PR policy passes when no vignette changes and accepts a
  generic nonempty `N/A`; the development log duplicates a single omic layer to
  enter HO-GSVD.
- **After:** policy-checker output rejects those PR bodies and accepts a complete
  proof packet; current docs run the registered exactly-one-omic-layer SVD
  workflow and show the calibration-only K=1 quasi-potential result.
- **Canonical location:** the PR body.
- **Current documentation:** concise development-log status/current workflow.
- **Claim status:** implementation proof only; K=1 scientific acceptance remains
  blocked by #51 and #67.

## Completion audit requirements

Before code review:

- Map every issue #68 implementation/testing/out-of-scope decision to a concrete
  file, GitHub issue/PR state, command, or rendered artifact.
- Run checker CLI tests, full R tests, package check, pkgdown build, image checks,
  ADR coverage, and registry compliance.
- Visually inspect the rendered #50 proof and record a cold-reader conclusion.
- Confirm all 23 previously open issues now contain required proof or explicit
  exemption language.
- Confirm the PR exists, links #50/#68, contains a complete proof packet, and CI
  is green or report any external blocker as incomplete.
- Only after this audit passes, run the repository two-axis code review against
  `ad77a2a`.
