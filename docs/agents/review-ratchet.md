# Review ratchet

Review knowledge must accumulate in the repository, not in a session. This is a
bounded, self-correcting queue of review knowledge only, not a style guide,
architecture record, domain glossary, or session log. Read it before substantial
work, maintain it in the triggering change, and report the disposition in every
pull request. ADR 0022 governs it.

Lifecycle: incident → review rule → recurring pattern → deterministic
enforcement → retire rule. Tests, hooks, linters, schemas, and CI outrank prose.

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

## Two-minute hygiene pass
Before substantial work, scan for contradictions with current authorities,
spot-check two or three entries against code or configuration, identify rules
ready to graduate, and consolidate duplicates. Near 150 lines, additions
require subtraction; a repeatedly full document signals missing enforcement.

Reporting “I could not satisfy this requirement because X” is a correct outcome;
inventing work to fill a ticket is not.

## Never-touch list
No entries yet; add one only after a concrete incident demonstrates a hazard.
## Earned defect checklist
### RR-001 — Wait for and monitor asynchronous reviewers
Do not treat a newly opened, green pull request as review-complete. Monitor every
requested asynchronous reviewer and inspect all threads before merge.
**Incident:** [PR #137](https://github.com/drejom/landscapeR/pull/137)
received two actionable findings after internal review; [PR #139](https://github.com/drejom/landscapeR/pull/139) required repeated manual prompts while Copilot reviews were pending.
### RR-002 — Send Markdown API bodies from files
Use a file-backed request body; never interpolate Markdown containing backticks.
**Incident:** [PR #137](https://github.com/drejom/landscapeR/pull/137) had a review reply corrupted by shell interpolation.
### RR-003 — Validate Markdown meaning, not template spelling
Policy parsers must accept equivalent Markdown forms; test semantic variants.
**Incident:** [PR #139](https://github.com/drejom/landscapeR/pull/139) initially rejected valid checkbox variants.
### RR-005 — Make governed identity behavioral and transactional
When governed identity authorizes registration or replacement, include captured
state across the lexical environment chain. Validate provenance before mutation;
test that failure leaves state and history unchanged.
**Incident:** [Issue #120 implementation review](https://github.com/drejom/landscapeR/issues/120#issuecomment-5150510334)
found body-only fingerprints, incomplete closure environments, and assign-before-
record ordering could hide behavior changes or leave an unprovenanced mutation.
### RR-006 — Verify that visual encodings carry independent meaning
Open every committed proof image and caption individually at canonical native and
reduced sizes before claiming visual proof; record filenames and result in the
pull request. Verify quantities, colours, captions against rendered marks/panels,
and recoverable annotations rather than mere files.
**Incident:** [PR #150](https://github.com/drejom/landscapeR/pull/150) misused focal
red; issue #212 found caption mismatches; issue #226 found clipped or colliding
marks; PR #240 showed proof files can pass link/test checks while titles, legends,
layout, and caption prose remain unacceptable.
### RR-007 — Keep transient roots outside package builds
Exclude repo scratch from Git and R package builds. Before trusting a package
check, verify generated sites, bundles, and prior checks missed the tarball.
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
and inspect the rendered body. Required proof paths must resolve to committed
files, and links must use the current full PR-head SHA, never a feature branch.
**Incident:** [PR #167](https://github.com/drejom/landscapeR/pull/167) claimed
invisible proof; [PR #182](https://github.com/drejom/landscapeR/pull/182) had
404 PNGs; [PR #207](https://github.com/drejom/landscapeR/pull/207) left broken
feature-branch links, leading to an audit of 46 images across 16 PRs.
### RR-013 — Replay governed artifacts after schema extensions
When typed results gain fields, replay every committed governed artifact through
its semantic verifier before merge. A declared migration must govern any change
to payload, order, digest, or caption; test actual producer-shaped evidence.
**Incident:** issue #67 added AML-only summary fields that passed focused tests
but broke phase-B1 artifact replay; issue #193's collector required fields its repeated producer never recorded.
### RR-014 — Compare governed identities independently of orchestration labels
When orchestration attaches labels, compare governed identities and required
order independently; reject missing, duplicate, unexpected, or reordered values.
**Incident:** issue #67 completed all 900 unique Gemini result branches, but its
collector rejected the valid ordered identities because `targets` branch names
were present on one character vector and absent from the other.
### RR-015 — Preserve typed non-estimability through aggregation
When a contract permits abstention, aggregation must retain the typed missing
estimate and diagnostic. Do not require finite values, substitute zero, or
weaken the model; continue rejecting infinite, nonnumeric, or malformed values.
**Incident:** issue #67 completed all 900 Gemini AML branches, but artifact
collection rejected 162 otherwise valid results whose required random-slope
models were singular and therefore returned `NA` target-effect estimates.
### RR-016 — Encode the complete RNG algorithm in deterministic streams
Constructed `.Random.seed` streams must encode and validate RNG kind, normal
generator, and discrete sampler under warnings-as-errors.
**Incident:** issue #190 review found package-derived L'Ecuyer streams used the
obsolete `Rounding` discrete sampler header. Nested bootstrap tasks emitted a
warning and became execution failures under `options(warn = 2)`.
### RR-017 — Never exercise acceptance task rows as smoke tests
Do not run, benchmark, or inspect acceptance rows before the revision-stamped
runner merges. Smoke tests use labelled development fixtures with disjoint RNG
streams; if acceptance ran early, retire its seed set and refreeze unchanged
science.
**Incident:** issue #193 ran version 3 smoke rows and later version 4 acceptance
branches before their runner revisions merged. Both complete seed sets were
retired; version 5 refroze unchanged science and reserved fixture RNG explicitly.
### RR-018 — Preserve public call sequences during infrastructure migrations
Retain arguments, paths, return shape, and verifier sequence, or provide a tested
migration path; exact-path compatibility must preserve raced destination data.
**Incident:** [PR #218](https://github.com/drejom/landscapeR/pull/218) reinterpreted `write_stage1_benchmark_artifact(path)` as a content-addressed root.
## Verify, never assume
A reviewer is not an oracle. Treat every finding as a claim to investigate; a
wrong fix is worse than a declined comment. If a finding is wrong, say so with
evidence. Tests, bots, documentation, and this Ratchet are evidence, not
oracles; when they disagree with observable repository state, investigate.

## Maintenance duties
Every agent that reads or benefits from this document owes these duties in the
same change as the triggering work:
- **Add:** record a new defect class only with a durable incident; reject speculation.
- **Correct:** fix or remove obsolete or misleading entries and report the correction.
- **Deduplicate:** search first; consolidate overlapping formulations.
- **Graduate:** move mechanical rules into deterministic enforcement and recurring
  decisions into ADRs, deleting detailed prose once no judgement remains.
- **Report:** select one PR disposition and give a substantive rationale.
