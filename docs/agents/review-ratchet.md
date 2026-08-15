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

Reporting “I could not satisfy this, because X” is correct; inventing work is not.
## Never-touch list
No entries yet; add one only after a concrete incident demonstrates a hazard.
## Earned defect checklist
### RR-001 — Wait for and monitor asynchronous reviewers
Do not treat a newly opened, green pull request as review-complete. Monitor every
requested asynchronous reviewer and inspect all threads before merge.
**Incident:** [PR #137](https://github.com/drejom/landscapeR/pull/137)
received two actionable findings after internal review; [PR #139](https://github.com/drejom/landscapeR/pull/139)
required repeated manual prompts while Copilot reviews were pending.
### RR-002 — Send Markdown API bodies from files
Use a file-backed request body; never interpolate Markdown containing backticks.
**Incident:** [PR #137](https://github.com/drejom/landscapeR/pull/137) had a review reply corrupted by shell interpolation.
### RR-003 — Validate Markdown meaning, not template spelling
Policy parsers must accept equivalent Markdown forms; test semantic variants.
**Incident:** [PR #139](https://github.com/drejom/landscapeR/pull/139) initially rejected valid checkbox variants.
### RR-005 — Make governed identity behavioral and transactional
When governed identity authorizes registration or replacement, include relevant
captured state across the lexical environment chain. Validate complete
provenance before mutation; test that failure leaves state and history unchanged.
**Incident:** [Issue #120 implementation review](https://github.com/drejom/landscapeR/issues/120#issuecomment-5150510334)
found that body-only fingerprints, incomplete closure environments, and
assign-before-record ordering could hide behavior changes or leave an
unprovenanced registry mutation.
### RR-006 — Verify that visual encodings carry independent meaning
Verify plotted quantities are independent and semantic colours retain their role;
captions must match rendered marks, omit absent encodings, narrate each panel,
and keep annotations/overlays recoverable at native and reduced reading sizes.
**Incident:** [PR #150](https://github.com/drejom/landscapeR/pull/150) plotted an
exact cosine transform and misused focal red; issue #212 review found endpoint
and A/B panel caption mismatches; issue #226 found clipped interaction intervals,
occluded comparison/critical-point marks, and tile-level visual collisions.
### RR-007 — Keep transient roots outside package builds
Exclude repo scratch from Git and R package builds. Before trusting a package
check, verify that generated sites, bundles, and prior checks missed the tarball.
**Incident:** [Issue #117](https://github.com/drejom/landscapeR/issues/117) found `.scratch/` entered `R CMD build` and exhausted file handles.
### RR-008 — Preserve orthogonal typed state during adaptation
Presentation adapters must not overwrite independent state such as availability.
Test typed state as well as prose.
**Incident:** issue #118 review found surface-caption adaptation replaced `partial` with `uncalibrated`.
### RR-009 — Observe governed identity independently
Never ask an artifact to echo expected identity. Read installation or build
metadata it cannot redefine; if absent, report unavailable or stop.
**Incident:** issue #134 review found remote workers could echo the expected SHA while running different installed code.
### RR-010 — Prove parallelism boundaries behaviorally
Do not infer parallelism boundaries from scheduling arguments. Exercise the
inner-sequential path under an ambient backend, and test private worker entry
points from an installed package. Track the complete HPC launcher and measure
worker reuse; nominal pool size can hide scheduler churn or ad hoc deployment.
**Incident:** issue #135 found hidden nested futures; issue #212 lost a private fitter on multisession; issue #193 recycled every worker after eight tasks.
### RR-011 — Keep backend-dependent measurements out of scientific decisions
Runtime and resource measurements may be retained for operational diagnostics,
but they must not affect candidate selection or the scientific evidence digest
when ADR 0018 promises backend-invariant evidence. Test that changing timing
alone leaves the scientific decision unchanged.
**Incident:** issue #135 review found that the elapsed-time ratio differed by
execution backend and was also used as a candidate-selection gate.
### RR-012 — Build and inspect pull-request bodies from the repository template
Read `.github/pull_request_template.md`, populate it from committed evidence,
and inspect the rendered GitHub body before review. Required proof must exist,
every repository-hosted proof path must resolve to its committed file or proof
directory, and each link must use the current full PR-head commit SHA. Never use
a feature-branch URL: deleting the branch after merge must not break the review
record.
**Incident:** [PR #167](https://github.com/drejom/landscapeR/pull/167) claimed
proof in a malformed body while none was visible. In [PR #182](https://github.com/drejom/landscapeR/pull/182),
two committed PNGs rendered as 404s because the body omitted `-surface`.
[PR #207](https://github.com/drejom/landscapeR/pull/207) rendered correctly
before merge but its proof URLs failed after the feature branch was deleted; a
repository-wide audit then found 46 broken images across 16 merged PRs and
feature-branch proof references in 42 historical PR bodies.
### RR-013 — Replay governed artifacts after schema extensions
When a typed result or summary gains phase-specific fields, replay every
committed governed artifact through its semantic verifier before merge. New
fields must not change the reconstructed payload, field order, digest, or
caption contract of an earlier artifact unless a declared migration governs
that change. Test validators with the actual producer-shaped evidence.
**Incident:** issue #67 added AML-only summary fields that passed focused tests
but broke phase-B1 artifact replay; issue #193's collector required fields its repeated producer never recorded.
### RR-014 — Compare governed identities independently of orchestration labels
When parallel orchestration attaches names or labels to a result container,
compare the governed identity values and their required order independently of
those incidental attributes. Continue to reject missing, duplicate, unexpected,
or reordered identities.
**Incident:** issue #67 completed all 900 unique Gemini result branches, but its
collector rejected the valid ordered identities because `targets` branch names
were present on one character vector and absent from the other.
### RR-015 — Preserve typed non-estimability through aggregation
When an analysis contract permits a method to abstain, aggregation and artifact
validation must accept the corresponding typed missing estimate and retain its
diagnostic. Do not require a finite value, substitute zero, or weaken the model
after the worker has correctly reported non-estimability. Continue to reject
infinite, nonnumeric, or structurally invalid estimates.
**Incident:** issue #67 completed all 900 Gemini AML branches, but artifact
collection rejected 162 otherwise valid results whose required random-slope
models were singular and therefore returned `NA` target-effect estimates.
### RR-016 — Encode the complete RNG algorithm in deterministic streams
Constructed `.Random.seed` streams must encode and validate the RNG kind, normal
generator, and discrete sampler, and work under warnings-as-errors.
**Incident:** issue #190 review found package-derived L'Ecuyer streams used the
obsolete `Rounding` discrete sampler header. Nested bootstrap tasks emitted a
warning and became execution failures under `options(warn = 2)`.
### RR-017 — Never exercise acceptance task rows as smoke tests
Do not run, benchmark, or visually inspect any task from a newly revealed
acceptance manifest before the revision-stamped runner has passed review and
merged. Integration smoke tests must use a separately labelled development
fixture with RNG streams that cannot enter acceptance evidence. If an
acceptance task is run early, retire the complete seed set and freeze a new
protocol without changing scientific settings in response to its outcomes.
**Incident:** issue #193 ran version 3 smoke rows and later version 4 acceptance
branches before their runner revisions merged. Both complete seed sets were
retired; version 5 refroze unchanged science and reserved fixture RNG explicitly.
### RR-018 — Preserve public call sequences during infrastructure migrations
Retain arguments, paths, return shape, and verifier sequence, or provide a tested
migration path. Exact-path compatibility must preserve raced destination data.
**Incident:** [PR #218](https://github.com/drejom/landscapeR/pull/218) reinterpreted `write_stage1_benchmark_artifact(path)` as a content-addressed root.
## Verify, never assume
A reviewer is not an oracle. Treat every finding as a claim to investigate. A
wrong “fix” is worse than a declined comment: respond with evidence when a
finding does not apply.
Before substantial work, scan for contradictions and spot-check relevant entries
against current code. Consolidate near 150 lines.
## Maintenance duties
- **Add:** record new defect classes with concrete incidents; reject speculation.
- **Correct:** fix or remove outdated entries and name the correction.
- **Deduplicate:** search before adding; consolidate overlapping rules.
- **Graduate:** move mechanical rules into checks and recurring decisions into ADRs.
- **Report:** select one disposition and give a substantive rationale.
This document is only for review knowledge; other concerns belong to their existing authorities.
