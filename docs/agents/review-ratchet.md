# Review ratchet

Review knowledge must accumulate in the repository, not in a session. Read the
relevant entries before substantial work and report the ratchet disposition in
every pull request. ADR 0022 governs this document.

## Gate sequence

Complete these gates in order for every implementation issue:

1. Implement with focused tests and complete package checks appropriate to risk.
2. Run the two-axis code review: specification compliance and code quality.
3. Open the pull request with its visual proof and ratchet disposition.
4. Run the standard `/review` pass.
5. Run `/review` again using `.github/copilot-instructions.md`.
6. Wait for the actual GitHub Copilot review to post.
7. Investigate every finding. Fix demonstrated defects; decline incorrect
   findings with concrete evidence.
8. After material fixes, rerun both review passes and affected checks.
9. Require green CI and zero unresolved review threads.
10. Resolve merge conflicts without discarding either intent, then revalidate.
11. Merge only after every preceding gate is satisfied.

Reporting “I could not satisfy this, because X” is a correct outcome. Inventing
work to fill a ticket is not.

## Never-touch list
No entries yet; add one only after a concrete incident demonstrates a context-specific hazard.

## Earned defect checklist

### RR-001 — Wait for asynchronous reviewers

Do not treat a newly opened, green pull request as review-complete. Wait for the actual GitHub Copilot review and inspect all threads before merge.
**Incident:** [PR #137](https://github.com/drejom/landscapeR/pull/137) received two actionable findings after internal review.

### RR-002 — Send Markdown API bodies from files

Do not interpolate Markdown containing backticks into shell command arguments; use a file-backed request body.
**Incident:** [PR #137](https://github.com/drejom/landscapeR/pull/137) had a review reply corrupted by shell interpolation.

### RR-003 — Validate Markdown meaning, not template spelling

Repository policy parsers must accept equivalent Markdown forms; test semantic variants, not one exact spelling.
**Incident:** [PR #139](https://github.com/drejom/landscapeR/pull/139) initially rejected valid checkbox variants.

### RR-004 — Monitor asynchronous review gates

After requesting an asynchronous reviewer, keep an active monitor on the pull request; do not leave polling to the user.
**Incident:** [PR #139](https://github.com/drejom/landscapeR/pull/139) required repeated manual prompts while Copilot reviews were pending.

### RR-005 — Make governed identity behavioral and transactional

When a callable implementation's governed identity authorizes registration or
replacement, include behavior-relevant captured state across the full lexical
environment chain. More generally, validate and prepare the complete
provenance record before mutating a governed store, and test that drift or
fingerprint failure leaves both state and history unchanged.

**Incident:** [Issue #120 implementation review](https://github.com/drejom/landscapeR/issues/120#issuecomment-5150510334)
found that body-only fingerprints, incomplete closure environments, and
assign-before-record ordering could hide behavior changes or leave an
unprovenanced registry mutation.

### RR-006 — Verify that visual encodings carry independent meaning

Before accepting a diagnostic relationship, verify that its plotted quantities
are not deterministic transforms of one another. Also verify that semantic
highlight colours retain their declared role rather than marking
result-selected extremes. A mathematically redundant or semantically overloaded
encoding can look informative while adding no evidence.

**Incident:** [PR #150](https://github.com/drejom/landscapeR/pull/150) initially
plotted one-dimensional principal angle against its exact absolute-cosine
transform and used the focal red for the three largest observed rotations.

### RR-007 — Keep transient roots outside package builds

A repo-root scratch directory must be excluded from both Git tracking and the R
source-package build. Before trusting a local package check, verify that its
generated site, bundles, and prior check directories were not copied into the
tarball. The mechanical rule belongs in `.gitignore` and `.Rbuildignore`.

**Incident:** [Issue #117](https://github.com/drejom/landscapeR/issues/117) found `.scratch/` entered `R CMD build` and exhausted file handles.

### RR-008 — Preserve orthogonal typed state during adaptation

When an adapter adds request-specific presentation or caption facts, it must
not overwrite an independent state dimension such as availability. Test the
typed state as well as the rendered prose: a caption can describe partial
evidence correctly while its enclosing object silently claims otherwise.

**Incident:** issue #118 review found surface-caption adaptation replaced `partial` with `uncalibrated`.

### RR-009 — Observe governed identity independently

Never verify an installed artifact by asking it to echo the expected identity.
Read identity from installation or build metadata that the job cannot redefine;
if that evidence is absent, report it as unavailable or stop at a boundary that
requires exact identity.

**Incident:** issue #134 review found remote workers could echo the expected SHA while running different installed code.

### RR-010 — Prove parallelism boundaries behaviorally

Do not infer that nested parallelism is disabled from a scheduling or chunking
argument. Exercise the declared inner-sequential path under an ambient parallel
backend and prove that work remains in the current worker.

**Incident:** issue #135 found `future.scheduling = 0` still creates one future and violates ADR 0018's single-layer policy.

### RR-011 — Keep backend-dependent measurements out of scientific decisions

Runtime and resource measurements may be retained for operational diagnostics,
but they must not affect candidate selection or the scientific evidence digest
when ADR 0018 promises backend-invariant evidence. Test that changing timing
alone leaves the scientific decision unchanged.

**Incident:** issue #135 review found that the elapsed-time ratio differed by
execution backend and was also used as a candidate-selection gate.

### RR-012 — Build and inspect pull-request bodies from the repository template

Before opening or updating a pull request, read `.github/pull_request_template.md`,
populate it from committed evidence, and inspect the rendered GitHub body. Do
not substitute a body from memory, claim unlinked proof, or defer an obvious
missing-proof failure to CI. Required proof must exist before review begins.

**Incident:** [PR #167](https://github.com/drejom/landscapeR/pull/167) claimed
rendered proof in a malformed free-form body while no proof was visible.

## Verify, never assume

A reviewer is not an oracle. Treat every finding as a claim to investigate. A
wrong “fix” is worse than a declined comment: respond with evidence when a
finding does not apply.

Before substantial work, scan for contradictions and spot-check relevant entries
against current code. Near 150 lines, perform a full consolidation pass.

## Maintenance duties

- **Add:** record new defect classes with concrete incidents; reject speculation.
- **Correct:** fix or remove outdated entries and name the correction.
- **Deduplicate:** search before adding; consolidate overlapping rules.
- **Graduate:** move mechanical rules into checks and recurring decisions into ADRs.
- **Report:** select one disposition and give a substantive rationale.

This document is only for review knowledge; other concerns belong to their
existing authorities.
