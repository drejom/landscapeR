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

No never-touch entries yet. Add one only when a concrete review incident
demonstrates that a file or action is unsafe in a specific context.

## Earned defect checklist

### RR-001 — Wait for asynchronous reviewers

Do not treat a newly opened, green pull request as review-complete. Wait for the
actual GitHub Copilot review and inspect all threads before merge.

**Incident:** [PR #137](https://github.com/drejom/landscapeR/pull/137) received
two actionable GitHub Copilot findings after its internal review passes.

### RR-002 — Send Markdown API bodies from files

Do not interpolate Markdown containing backticks into shell command arguments.
Use a file-backed request body so the shell cannot execute or corrupt its text.

**Incident:** [PR #137](https://github.com/drejom/landscapeR/pull/137) had a
review reply corrupted when Markdown code spans were passed through the shell.

### RR-003 — Validate Markdown meaning, not template spelling

Repository policy parsers must accept equivalent ordinary Markdown forms. Test
semantic variants instead of requiring one exact bullet, spacing, or case style.

**Incident:** [PR #139](https://github.com/drejom/landscapeR/pull/139) initially
rejected valid indented and alternate-bullet disposition checkboxes.

### RR-004 — Monitor asynchronous review gates

After requesting an asynchronous reviewer, keep an active monitor on the pull
request. Do not end with a static “pending” report and rely on the user to poll.

**Incident:** [PR #139](https://github.com/drejom/landscapeR/pull/139) required
repeated manual status prompts while successive Copilot reviews were pending.

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

**Incident:** [Issue #117 implementation](https://github.com/drejom/landscapeR/issues/117)
found that `.scratch/` was gitignored but still entered `R CMD build`, adding
thousands of generated pkgdown files and exhausting file handles during check.

### RR-008 — Preserve orthogonal typed state during adaptation

When an adapter adds request-specific presentation or caption facts, it must
not overwrite an independent state dimension such as availability. Test the
typed state as well as the rendered prose: a caption can describe partial
evidence correctly while its enclosing object silently claims otherwise.

**Incident:** issue #118 implementation review found that surface-caption
adaptation replaced a valid `partial` evidence state with `uncalibrated`.

### RR-009 — Observe governed identity independently

Never verify an installed artifact by asking it to echo the expected identity.
Read identity from installation or build metadata that the job cannot redefine;
if that evidence is absent, report it as unavailable or stop at a boundary that
requires exact identity.

**Incident:** issue #134 implementation review found that remote workers could
pass revision preflight by echoing the controller-propagated expected SHA while
running different installed code.

### RR-010 — Prove parallelism boundaries behaviorally

Do not infer that nested parallelism is disabled from a scheduling or chunking
argument. Exercise the declared inner-sequential path under an ambient parallel
backend and prove that work remains in the current worker.

**Incident:** issue #135 implementation found that `future.scheduling = 0`
still creates one future and therefore did not enforce ADR 0018's single-layer
parallelism policy.

## Verify, never assume

A reviewer is not an oracle. Treat every finding as a claim to investigate. A
wrong “fix” is worse than a declined comment: respond with evidence when a
finding does not apply.

Before substantial work, scan relevant entries, check for contradictions, and
spot-check two or three against current code or documentation. When this file
approaches 150 lines, perform a full consolidation pass.

## Maintenance duties

- **Add:** record a new defect class in the triggering PR, with a concrete
  incident. No incident means speculation and must not be added.
- **Correct:** fix or remove an outdated entry and name the correction in the
  commit and PR disposition.
- **Deduplicate:** search before adding; consolidate overlapping rules.
- **Graduate:** move mechanical rules into tests or lint checks and recurring
  architecture or scientific decisions into ADRs. Remove redundant prose or
  retain only a compact link.
- **Report:** select exactly one PR disposition: unchanged, updated, corrected,
  deduplicated, or graduated. Give a substantive rationale for every choice.

This document is only for review knowledge. Implementation conventions, domain
vocabulary, session history, scheduling, and one-off decisions belong to their
existing authorities.
