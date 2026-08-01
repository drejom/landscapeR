# landscapeR Technical Debt Report

> Archived audit record. Follow-up work is tracked in GitHub issues; this file
> does not own scheduling.

**Date:** 2026-07-31
**Method:** Full-codebase audit by 9 parallel technical-debt-manager agents, one per subsystem, each with read-only access to source + tests + relevant ADRs/docs. This is the first such audit of the repository. Findings below are deduplicated and cross-referenced where multiple agents independently surfaced the same issue. Severity is High/Medium/Low as assigned by each subsystem agent; cross-cutting issues are called out explicitly.

**Scope covered:** ~20,000 lines of R across 37 files in `R/`, ~9,800 lines of tests, 20 ADRs, ROADMAP.md, CLAUDE.md, CI/compliance tooling, and repo hygiene.

---

## Executive summary

The codebase is in noticeably better shape than a typical ~20K-line R package at this stage of iteration: every agent independently confirmed that the registry/contract/provenance architecture (rules 1–9 in CLAUDE.md) is honored structurally in the overwhelming majority of code, boundary validation is genuinely enforced (not aspirational), CI compliance scripts (`check-roadmap.py`, `check-adr-coverage.py`, `check-registry-compliance.sh`) all pass and are wired into required CI jobs (not paper tigers), and test coverage is generally thorough at the integration level.

That said, nine subsystem audits converged on a small number of **real, fixable** problems, several of which recur across subsystems and should be treated as a coherent theme rather than nine unrelated punch lists:

1. **A confirmed scientific-correctness bug**: the multiple-comparison correction method (Holm vs BH) silently differs across three structurally parallel code paths that should be identical, contradicting the accepted ADR text.
2. **Raw exceptions instead of typed failures at real system boundaries** in several places that matter most: the two production HO-GSVD strategies, Stage 2 KDE's external `ks::` calls, `19-analysis-specification.R`'s constructor, and `13a-plot-theme.R`.
3. **A registry-integrity gap**: `register_strategy()` silently overwrites an existing strategy name with no collision check — a single-point risk to the "registry, not switch statements" guarantee.
4. **Silent-cap / silent-drift risk in exactly the places CLAUDE.md warns about**: an out-of-range layer index in `project_into()` is silently clamped rather than rejected; `synthetic_potential_control()` (Stage 0 — "the evidence oracle") has no input validation and can silently produce NaN-filled ground truth.
5. **Governance duplication**: two different files both claim ADR number 0020 with contradictory status (`provisional-accepted` vs `accepted`), and a stale expert-review doc still points at the wrong one.
6. **File-size/structural debt concentrated in one file**: `R/13b-component-interpretation.R` (~4,000 lines, the highest-churn file in the repo) has outgrown the split pattern the rest of the interpretation subsystem (`13c`–`13g`) already adopted.
7. **Duplicated logic across parallel "joints"** (independent vs. repeated time-course; HO-GSVD averaged vs. prereduced; two typed visual-evidence systems in `13f`/`13g`) that rule 9 says should be abstracted but isn't yet.

None of the findings are blocking or indicate the architecture is unsound — the pattern throughout is "the discipline exists and mostly works, but has a few gaps that will compound if left."

---

## Priority punch list (recommended order of attack)

| # | Finding | Severity | Files |
|---|---|---|---|
| 1 | Holm vs BH multiple-comparison correction diverges across cross-sectional / independent-time-course / repeated-time-course paths, contradicting ADR 0020 | **High** | `R/13b-component-interpretation.R:1514,1598`, `R/13c:1213`, `R/13d:1085` |
| 2 | `decisions/0020-*` — two files, same ADR number, contradictory status; stale review doc points at wrong one | **High** | `decisions/0020-stage1-component-interpretation-statistical-strategy.md`, `decisions/0020-stage1-component-interpretation-strategy.md`, `docs/reviews/adr-0020-expert-review-record.md` |
| 3 | `register_strategy()` silently overwrites an existing key — no collision check | **High** | `R/07-registry.R:14-17` |
| 4 | HO-GSVD strategies (`hogsvd_averaged`, `hogsvd_prereduced`) raw-crash instead of typed failure on the exact heterogeneous-feature-space case ADR 0001 identifies as open | **High** | `R/12-stage1-hogsvd.R:118-151` |
| 5 | `synthetic_potential_control()` has no input validation and can silently emit NaN-filled ground truth (Stage 0 is "the evidence oracle") | **High** | `R/13-stage0-synthetic.R:851-919` |
| 6 | `project_into()`: silent out-of-range clamp on `layer_secondary`, dead `layer_primary` parameter, no feature-space alignment check | **High** | `R/17-project.R:39,52,63` |
| 7 | `execute_stage1_benchmark_full()` — the function that produces the accepted evidence artifact — has zero test coverage | **High** | `R/23-stage1-execution.R:497-537` |
| 8 | `R/13b-component-interpretation.R` (~4,000 lines, highest churn in repo) should be split along 4 seams (shared helpers / cross-sectional strategies / proposal-confirmation API / plotting) matching the pattern `13c`–`13g` already follow | **High** (structural) | `R/13b-component-interpretation.R` |
| 9 | No K=1 (single-component) identifiability test exists, despite K=1 being the package's only currently-accepted Stage 1 configuration | **High** | `R/13e-axis-identifiability.R`, `tests/testthat/test-axis-identifiability*.R` |
| 10 | Two independently-invented typed-evidence systems (`VisualEvidenceView` vs `StagePlotEvidence`) solve the same problem with no shared contract | **High** (design) | `R/13f-visual-evidence-adapters.R`, `R/13g-stage-plot-evidence.R` |
| 11 | Stage 2 KDE bandwidth is still effectively hard-coded (`ks::hpi` only) despite ADR 0002 promising sweepability; no error handling around `ks::` calls on degenerate input | **High/Medium** | `R/15-stage2-kde.R:73-79` |
| 12 | `19-analysis-specification.R` uses 14+ raw `stop()` calls instead of the typed `landscapeR_validation_error` convention used everywhere else (incl. its sibling `18-sampling-design.R`) | **Medium** | `R/19-analysis-specification.R` |
| 13 | Hard-coded hex color drift: `13f-visual-evidence-adapters.R` reimplements the binary semantic scale with a *different* focal red (`#B2182B`) than the canonical palette (`#C43C39`); `#111111` ink hard-coded 16+ times outside the theme file | **High/Medium** | `R/13f-visual-evidence-adapters.R:629-639`, `R/13b`, `R/14` |
| 14 | `13a-plot-theme.R` uses raw `stop()` instead of `.stop_landscapeR_validation()`, inconsistent with its own sibling files | **Medium** | `R/13a-plot-theme.R` |
| 15 | Extensive duplication between `R/13c` (independent time-course) and `R/13d` (repeated time-course): 6+ near-identical helper blocks, with `13d` silently depending on functions defined in `13c` with no structural marker | **Medium** | `R/13c`, `R/13d` |

---

## Findings by subsystem

### 1. Core plumbing & contracts (`R/00`–`R/11`)

**High**
- `R/07-registry.R:14-17` — `register_strategy()` silently overwrites an existing `contract:name` key with no warning or collision check (verified live: a same-named registration replaces a real strategy with a dummy one, with zero diagnostics). This is the single point of trust for rule 7 ("registry, not switch statements"). **Fix:** error (or at least warn) on collision unless `overwrite = TRUE` is passed; add a regression test.
- No exported `PipelineConfig()` constructor exists (unlike `StateTransitionData()`); every call site must use `new("PipelineConfig", ...)` directly and remember that `analysis` is mandatory. **Fix:** add a documented constructor mirroring `StateTransitionData()`.

**Medium**
- `R/03-container.R:46-54,69-84` — `StateTransitionData` defaults are defined in three places at once (class prototype, `setAs` coercion, constructor re-application), risking drift on schema changes.
- `R/06-provenance.R:41-49` — `record_provenance()`'s default `input_hashes` hashes the *entire* incoming object including its own growing provenance history, so identical scientific data run twice with different upstream stage counts yields different hashes. Every real call site already overrides this default, meaning the default itself is a dead, inconsistent fallback. **Fix:** make `input_hashes` a required argument, or hash a provenance-stripped view.
- `R/08-contracts.R:162-175,287-321` — the core dispatch layer reaches directly into `metadata(result@value)[["stage1"]]`/`[["stage2"]]` — exactly the informal-metadata-as-public-API pattern CLAUDE.md warns against. **Fix:** introduce a typed accessor (`stage1_result()`/`has_stage1_result()`) instead of indexing `metadata()` directly.
- `R/04a-decomposition-result.R:86-138` — eight accessor functions (`dr_V_star`, `dr_sigma`, etc.) repeat an identical 4-line guard clause; factor into one internal helper.
- No dedicated test file for `DecompositionResult` construction/validity — none of the five validity-error branches in `setValidity("DecompositionResult", ...)` are directly unit-tested.

**Low**
- `TopologyGroundTruth` is exported but never constructed anywhere (expected — Stage 0.5 deferred contract surface — but worth a comment so it isn't mistaken for an oversight).
- `ProvenanceStep@rng_seed` captures the full `.Random.seed` (626 ints) but nothing in the codebase ever reads it back for replay — currently write-only.
- `R/00-package.R:7` imports `future::plan`, but `future` is absent from CLAUDE.md's documented core `Imports` list — dependency-declaration drift, worth reconciling either direction.
- `validate_boundary()`'s `required_schema` parameter is unused by every production call site (only exercised directly in `test-boundary.R`) — a test seam, not a bug.

**Health:** Genuinely strong. Every stage generic is gated by a structural, non-bypassable `validate_boundary()` call; registry/migration/provenance machinery all have direct unit tests; typed `StageResult` failures are used consistently. The registry collision gap is the one item worth prioritizing before more strategies are authored concurrently.

---

### 2. Stage 1 decomposition, execution & Stage 2 KDE (`R/12`, `R/15`, `R/20`–`23`)

**High**
- `R/12-stage1-hogsvd.R:118-151`, `R/12a-stage1-svd.R:26-56` — `HogsvdAveraged`/`HogsvdPrereduced` have no input validation (unlike `SvdDecomposer`, which validates `center`/`k_components`/finiteness). Confirmed: feeding two layers with different feature counts through `hogsvd_averaged` throws a raw, uncaught `simpleError` instead of a `StageResult` failure — a direct rule-5 violation, and exactly the heterogeneous-feature-space case ADR 0001 calls out as the open problem. **Fix:** add the same guard class `SvdDecomposer` has, plus a same-`p`-across-layers check, returning `stage_failure()`.
- ADR 0001's mandate to register the Kempf rank-deficient HO-GSVD is not honored — only the pre-reduction/averaging heuristic is registered; two evaluated prototype candidates (`C1_symmetric_consensus`, `C2_block_scaled_svd`) sit in an unregistered, non-`Decomposer` code path with no production entry point. Consistent with ADR 0001's currently "reopened" status, but the file's own docstring overstates production readiness relative to that status. **Fix:** update the file-header docstring to state the legacy/equal-feature-space scope explicitly.
- `execute_stage1_benchmark_full()` (`R/23-stage1-execution.R:497-537`) — the function that runs the full frozen grid and atomically publishes the content-addressed evidence artifact consumed by committed-artifact tests — has **zero** test coverage; only its development sibling is tested. **Fix:** add a fast, reduced-manifest end-to-end test.

**Medium**
- BBP-threshold warning message contains a literal embedded newline + indentation, corrupting `warning()` output, duplicated identically in both HO-GSVD strategies.
- ~50 lines duplicated almost verbatim between `HogsvdAveraged` and `HogsvdPrereduced` `.decompose_impl` methods (hash computation, layer extraction, BBP check, provenance, return) — any fix (including the newline bug above) must be applied twice and already wasn't kept in sync.
- `R/15-stage2-kde.R:74` — KDE bandwidth is hard-coded to `ks::hpi()` with no config override, despite ADR 0002 explicitly requiring bandwidth to be sweepable in Stage 0 (unlike `poly_degree`, which *is* configurable). **Fix:** add a `bandwidth`/`bandwidth_method` param to `KdeLogDensityEstimator@params`.
- `R/15-stage2-kde.R:73-79` — no error handling around `ks::hpi()`/`ks::kde()`; confirmed a degenerate (zero-variance) input crashes with a raw `simpleError` rather than `stage_failure()`. Malformed `n_grid`/`poly_degree` similarly crash raw. **Fix:** wrap in `tryCatch()` mirroring the existing pattern at line 181; validate params up front.
- `.stage1_execute_tasks()` (`R/22-stage1-evidence.R:246-257`) appears to be dead code — never called from production, only from its own test; a differently-named sibling (`.stage1_execution_tasks()` in `R/23`) is what's actually used. Readability/maintenance trap (easy to patch the wrong one).
- `k_components` validation is inconsistent across the three `Decomposer` strategies registered under the same interface — `SvdDecomposer` rejects bad input cleanly, HO-GSVD strategies don't.

**Low**
- `R/20-stage1-prototype-smoke.R:216-241` — hard-coded iteration cap (100) and tolerance (1e-8) in prototype-only code; flag for a future ADR if promoted to production.
- `R/23-stage1-execution.R` (537 lines) mixes manifest construction, workspace/checkpoint lifecycle, and platform-specific parallel execution in one file — candidate for a future split, not urgent (infrastructure code, not scientific algorithm).
- BBP formula exponent (`(n*p)^0.25`) has no inline citation comment (only in the ADR).

**Health:** The registered strategies correctly follow the registry/contract/provenance architecture, and the Stage 0 evidence machinery (hash-verified, content-addressed artifacts, typed-failure negative controls) is unusually rigorous for an R package. Priority gaps: HO-GSVD raw-crashes on the exact case ADR 0001 flags as open, KDE bandwidth hard-coding contradicts ADR 0002, and the artifact-producing benchmark function is untested.

---

### 3. Stage 0 synthetic controls, sampling design & analysis specification (`R/13`, `R/17`–`19`)

**High**
- `R/17-project.R:63` — `project_into()` silently **clamps** an out-of-range `layer_secondary` (`min(as.integer(layer_secondary), length(expt_sec))`) instead of failing — exactly the "no silent caps" anti-pattern the project explicitly warns against, and confirmed to have zero test coverage. **Fix:** hard bounds check + typed validation error.
- `R/17-project.R:39,52` — the documented `layer_primary` parameter is accepted but never actually used in the function body; callers who set it are silently misled. **Fix:** remove the parameter/doc claim, or wire it up.
- `R/17-project.R` — no feature-space alignment check between primary and secondary cohorts; projecting an unrelated dataset with matching dimensions but unrelated features succeeds silently with no warning. This is the entire point of the AML primary/validation-cohort workflow the function exists for. **Fix:** require and check rowname/feature-identity alignment before multiplying.
- `R/13-stage0-synthetic.R:851-919` — `synthetic_potential_control()` has no input validation, unlike its three sibling generators. Confirmed: `n=0` throws a raw opaque error; `beta=-1` silently produces an all-NaN coordinate matrix and returns as if successful; non-integer seeds are silently truncated. Given Stage 0 is explicitly "the evidence oracle for every scientific strategy," a control that can silently degenerate into NaN ground truth is a real correctness risk. **Fix:** add a validation helper mirroring the other three generators.

**Medium**
- Inconsistent provenance recording across the four Stage 0 generators: `synthetic_control()` only records provenance when K==1; `synthetic_potential_control()` never records it at all — an apparently unintentional asymmetry (rule 8 violation).
- `control_ladder()` has zero test coverage and no per-cell error isolation in its sweep loop — a single failing grid point aborts the entire sweep with no partial results.
- The v1→v2 `AnalysisSpecification` migration path is exercised only via a static `.rds` fixture with no generation script in the repo, and loading it directly produces silently-swallowed S4 validity warnings — the fixture's provenance is unauditable.
- `R/19-analysis-specification.R` uses 14+ plain `stop()` calls instead of the typed `landscapeR_validation_error` convention used consistently everywhere else, including its sibling `R/18-sampling-design.R` — meaning a caller cannot `tryCatch` distinguish an analysis-spec input error from an unrelated bug on one of the package's most safety-critical validation surfaces.

**Low**
- Unexplained magic scale-factor constants (`1.8`, `1.25`, etc.) in `synthetic_branching_control()` — lower stakes since it's explicitly `calibration_only`.
- The shared `.stop_landscapeR_validation()` helper is defined inside the Stage-0-synthetic file but reused by `18-sampling-design.R`, which is a discoverability problem — consider relocating to a shared low-numbered file.
- `.validate_sampling_design_data()`'s "no repeats" error doesn't name the offending subject IDs, making debugging real datasets harder.

**Health:** Generally well-disciplined (typed validation, deterministic seeding, explicit provisional labeling) in three of four generators. `synthetic_potential_control()` and `project_into()` are clear outliers and should be the near-term priority since both are used in real (AML) workflows with no current safety net.

---

### 4. Component interpretation (`R/13b`, ~4,000 lines)

**File size / decomposition (explicit recommendation)**

`R/13b-component-interpretation.R` is the largest file in the package and also the highest-churn (28 commits in the last 90 days — more than any other file). The rest of the interpretation subsystem (`13c`, `13d`, `13e`, `13f`, `13g`) has already been split out of what was presumably once a larger monolith and correctly reuses shared helpers still living in `13b`. No dead/half-finished #55 scaffolding was found — the size reflects legitimate breadth, not stubs — but that's exactly the argument for splitting proactively rather than after the fact. Recommended 4-way split:
1. **Shared helpers** (`.signed_rank_biserial`, `.resampling_summary`, `.aligned_component_metadata`, `.nuisance_design`, digest helpers) — consumed by `13c`/`13d` today, so extracting them makes the cross-file dependency explicit rather than accidental.
2. **Cross-sectional association strategies** (the three registered `AssociationStrategy` classes, `.associate_cross_sectional` — at 494 lines, the single largest function in the file) — would mirror the "one file per sampling design" pattern `13c`/`13d` already follow.
3. **Proposal/confirmation/abstention API** (`propose_component`, `confirm_component`, `ComponentProposal`/`ComponentAbstention`/`PermutationEvidence`) — sampling-design-agnostic top-level API.
4. **Plotting** (`plot.MetadataAssociationAtlas`, `plot.ComponentProposal`, etc.) — Stage 1 already has a separate plotting file; this is precedent to follow.

**High**
- `.associate_cross_sectional` (lines 1230-1723, 494 lines) does validation, iteration, strategy resolution, computation, resampling, BH adjustment, and table assembly all in one function with 5-6 levels of nesting — the primary correctness surface for issue #55 and the hardest function in the package to safely review or modify.
- Component-tie detection at line 2950-2951 uses **exact floating-point equality**, not the "calibrated near-tie margin" ADR 0020 calls for (deferred to #67) — meaning `propose_component()` will almost always find a "unique" winner even when two components are practically indistinguishable. Tracked debt, not a rule violation, but should not be forgotten — add a code comment pointing at the ADR section.
- `plot.MetadataAssociationAtlas` vs `plot.ComponentProposal` — ~90-139 lines of near-duplicated ggplot layer construction that has already begun to drift incidentally (facet strategy, axis expansion) beyond their intentional differences.

**Medium**
- `.adjusted_rank_score_effect` and `.adjusted_resampled_estimate` independently re-implement the same QR/lm.fit residualization sequence rather than sharing a primitive — a numerical-stability fix to one is likely to miss the other.
- Bootstrap CI method (`probs = c(0.025, 0.975), type = 6`) is a hard-coded literal with no `PipelineConfig`/named-constant tie-back to the ADR's stated calibration process.
- The minimum-sample-size literal `< 3L` is repeated independently at 6 call sites with no shared named constant — exactly the kind of ad hoc threshold ADR 0020 says must not be inferred from rules of thumb.
- Sampling-design dispatch (`associate_metadata`, `.compute_permutation_evidence`) uses sequential `if (identical(kind, "..."))` checks rather than registry lookup — explicitly sanctioned by ADR 0020 as "structural contract dispatch," but worth a comment capping it at the three ADR-named kinds so a future fourth design doesn't get bolted on the same way without reconsidering registry dispatch.

**Low**
- `confirm_component()` (183 lines) is branchy but each branch traces 1:1 to an ADR 0020 §8 rule and is heavily tested — low risk, refactor-for-readability only.
- Recurring literal hex colors/style constants across all five `plot.*` methods with no shared constants (ties into the cross-cutting color-drift finding below).
- No missing roxygen or missing tests were found for any of the 44 exported functions — test coverage here is a genuine strength (1,445-line test file, 35 test blocks covering binary/continuous/ordered/adjusted paths, abstention boundaries, serialization).

**Health:** Scientifically well-specified (every design choice traces to an ADR) and well-tested; the debt is structural/maintainability (size, churn, a few pending near-tie calibration items already tracked against #67), not correctness.

---

### 5. Time-course interpretation (`R/13c`, `R/13d`)

**High**
- **Confirmed correctness bug**: `R/13c:1213` uses `p.adjust(method = "holm")` while the structurally parallel `R/13d:1085` uses `method = "BH"` for the identical per-component q-value calculation. ADR 0020 explicitly specifies Holm (citing its validity "under arbitrary assumptions" — precisely the correlated-subject case repeated time-course needs), yet the cross-sectional path (`R/13b:1514,1598`) *also* uses BH — meaning the accepted ADR text was implemented in exactly one of three symmetric code paths. **Fix:** reconcile all three call sites against ADR 0020 (or update the ADR if BH was a later decision), and centralize into one shared constant/helper so this can't diverge again.
- Inconsistent, undocumented `diagnostic_prefix` conventions between `13c` (default `"non-identifiable-design:"` prepended to bare callee diagnostics, no space) and `13d` (callee diagnostics are pre-prefixed with `"non-identifiable-design: "`, caller passes `""`) — functionally consistent today only by accident of two independent conventions; a future edit to either fitter's diagnostic strings would silently double- or un-prefix with nothing but substring greps to catch it. **Fix:** make diagnostic-string construction the sole responsibility of one shared helper.

**Medium**
- `R/13d:264-274` hard-codes `< 3L` minimum-observations/minimum-distinct-times-per-subject thresholds with no config surface — and ADR 0020 *explicitly states* "no literature rule-of-thumb is promoted into a package support limit; synthetic sweeps must establish the supported range," making this a direct textual acknowledgment that `3` is a placeholder sitting uncommented in production control flow.
- lme4 optimizer tolerances (`maxfun=100000`, `tol=1e-4`) are hard-coded and duplicated across 5 locations including provenance recording — any change to one without the others silently desyncs the recorded provenance from the actual fit tolerance (rule 8 risk).
- The interaction-coefficient regex `"^target.*:scaled_time$"` is duplicated 4 times across both files with no shared constant.
- **No `validate_boundary()` call anywhere in the time-course pipeline** — both association functions use ad hoc `is()`/`.stop_landscapeR_validation()` checks instead of the package's designated boundary-validation entry point used at Stage 1/Stage 2. Package-wide inconsistency, not `13c`-vs-`13d`-specific.

**Cross-file duplication (13c vs 13d)** — concrete, byte-for-byte duplicated blocks:
- Nuisance-reference-value computation for display lines (`13c:876-882` / `13d:760-767`)
- Fitted-score reconstruction from coefficients (`13c:883-888` / `13d:768-773`)
- `target_name`/`interaction_name` coefficient extraction (`13c:862-868` / `13d:747-753`)
- `study_time_range` fallback logic (`13c:314-320` / `13d:390-396`)
- The two display-line functions share ~60% of their body verbatim around a small, legitimately-different core (grid density).
- `13d` silently depends on 8 functions defined in `13c` (`.time_values_numeric`, `.time_course_association_row`, etc.) with no structural marker of the cross-file dependency — deleting/editing one in `13c` without realizing `13d` needs it would break silently.

**Low**
- `.time_values_numeric()` silently coerces unrecognized time-column types via `as.numeric()` rather than raising a typed validation error — malformed input degrades to NAs that surface only indirectly downstream.
- Both `.associate_independent_time_course` and `.associate_repeated_time_course` are ~550-600 lines, mixing validation/filtering/fitting/resampling/provenance in one function each.

**Recommendation:** extract the genuinely-shared helpers (items above) into a new `13c0-time-course-shared.R` so the `13c`→`13d` dependency becomes structural rather than accidental, and resolve the Holm/BH divergence as a priority correctness fix.

**Health:** Functionally solid and well-tested at the integration level, but the Holm/BH mismatch is a live, concrete scientific-correctness bug, and ~150 lines of genuinely identical logic sitting invisibly cross-file is a real drift risk (as the q-value bug itself demonstrates).

---

### 6. Axis identifiability (`R/13e`, ~1,900 lines)

**High**
- Two byte-for-byte identical 13-line failure-handling blocks inside `.run_identifiability_replicate()` (lines ~578-598 and ~606-627) — any future change to what evidence a failed replicate retains must be made in two places.
- Two textually identical `make_draw` bootstrap closures across the `cross_sectional` and `independent_time_course` branches of `.identifiability_resampling_plan()` — combined with a 3-way `if/else if/else` dispatch on `design@kind`, arguably in tension with rule 7. **Fix:** extract a single `.stratified_unit_bootstrap_draw()` helper; consider whether this dispatch belongs behind the registry given `SamplingDesign@kind` is a closed, validated enum.
- **No K=1 (single-component) identifiability test exists**, despite K=1 being the package's only currently-accepted Stage 1 configuration per the roadmap. Several functions (`.match_component_loadings`, `.competing_loading_assignments`, `.identifiability_recurrence`) have `n_reference`-dependent branches (e.g. `similarity[i, -j]` behaving specially when only one component exists) that are never exercised at K=1. This is the exact "adversarial tests exist but retrofitted around known-fragile behavior" risk the audit was asked to check for, and it's a coverage gap in the package's actual shipped scientific configuration. **This should be the first fix in this subsystem.**

**Medium**
- `.run_identifiability_replicate()` (141 lines) is the file's most complex function, interleaving resampling/decomposition/three-stage tryCatch/alignment/evidence assembly with the duplicated failure blocks embedded inside it.
- Repeated `data.frame(surface=, evidence_index=, value=, series=, focal=)` literal construction (~13 call sites across two functions) with no shared row constructor.
- `plot_component_identifiability()` (252 lines, longest function in the file) builds two structurally different ggplot objects inline rather than as separate helpers.
- Parallel execution strategy (`future.apply::future_lapply`) is hard-coded with no config knob and isn't recorded in the evidence payload's provenance — a rule-8 gap (nothing records *how* a given evidence artifact's resampling was executed).
- `.identifiability_non_analytical_fields()` accepts a `proposal` argument it never uses — reads as an incomplete stub.
- None of 19 distinct validation error messages in this file are directly exercised by `expect_error()` in any test file — only indirect coverage via other error strings.

**Low**
- Large inline lookup tables for caption prose repeat the same 7-item `structured_outcome` enum as literal keys in three separate places, with a silent generic fallback for unrecognized values rather than a loud failure (in tension with rule 5's typed-failure ethos, though currently unreachable since only `"not-calibrated"` is set in production).

**Health:** Functionally dense but structurally disciplined — every exported function has roxygen + generated docs, all error paths are typed, no hard-coded p-value/calibration thresholds exist (correctly deferred to #67), and tests exercise real adversarial scientific scenarios. Debt here is duplication (increasing the risk a fix applied to one copy is missed in its twin), not fragility. The missing K=1 test is the one genuine coverage gap that matters given what the package actually ships today.

---

### 7. Caption contract, resampling policy, visual evidence view, plot theme (`R/13a-*`)

**High**
- `R/13f-visual-evidence-adapters.R:629-639` hand-rolls `scale_colour_manual`/`scale_fill_manual` reimplementing the binary semantic scale, but uses `#B2182B` for the focal colour instead of the canonical `landscapeR_palette("semantic")[["focal"]]` (`#C43C39`) — bypassing `scale_colour_landscapeR()` entirely and creating a visible, real color inconsistency across the package's own figures. **Fix:** replace with `scale_colour_landscapeR("binary", ...)`.
- The ink colour `"#111111"` is hard-coded 16+ times across `13b` and `14` instead of sourced from `landscapeR_palette("semantic")[["ink"]]` — exactly the "hard-coded colors that should be centralized config" pattern the theme file exists to prevent.

**Medium**
- `13a-plot-theme.R` uses raw `stop(..., call.=FALSE)` throughout instead of `.stop_landscapeR_validation()`, inconsistent with all three sibling `13a-*` files (39 combined typed-error call sites between them) — a caller can't uniformly catch `landscapeR_validation_error` across the theme module.
- `test-plot-theme.R` has zero `expect_error` assertions for most of `theme_landscapeR()`/`landscapeR_palette()`/`save_landscapeR_plot()`'s validated parameters — these boundary checks are currently unverified.
- The scientific-caption renderer registry (`13a-scientific-caption-contract.R:368-379`) hard-codes 10 plot function names as a literal list that must be kept in sync with actual exports by hand; drift is only caught by a test, not at build/load time.
- No in-file documentation of the accounting invariants (`n_completed + n_failed == n_requested`, every failure carries a code) in `13a-resampling-policy.R` — the single shared engine behind every resampling lifecycle in the package, and the exact file two recent "no silent caps" fix commits already had to patch.

**Low**
- Duplicated `n`-positive-integer validation block between `landscapeR_palette()`'s categorical and binary branches.
- A test-only diagnostic function (`.plot_caption_contract_diagnostic()`) lives in production code rather than a test helper.
- `VisualEvidenceView@caption_view` is typed `"ANY"` rather than a proper class constraint, relying entirely on `setValidity` discipline rather than the slot type itself.

**Health:** Better than typical — resampling-policy, caption-contract, and visual-evidence-view files consistently use typed validation, digest-verified payloads, and registry-enforced renderer coverage; all four test files pass cleanly. The real debt is at the boundary between the theme file (under-validates) and its consumers (routinely bypass the centralized palette/scale helpers with hard-coded hex, including one outright semantic drift a side-by-side figure comparison would visibly catch).

---

### 8. Visual evidence adapters, stage plot evidence, stage plots (`R/13f`, `R/13g`, `R/14`, `R/16`)

**High**
- `VisualEvidenceView` (`13a`/`13f`) and `StagePlotEvidence` (`13g`) are **two independently-designed, structurally near-identical typed-evidence containers** solving the same "typed evidence for rendering" problem, invented separately for the same problem class (introduced in the same feature arc, #94/#114). Neither shares a class hierarchy, validation helper, or digest/staleness convention — `StagePlotEvidence` has staleness/digest checking that `VisualEvidenceView` conspicuously lacks. **Fix:** file an ADR proposing a single shared typed-evidence base/mixin before a third parallel pattern gets invented for a future stage.
- `plot_potential()` and `plot_components()`/`plot_decomposition()` each independently inline metadata-alignment/missingness-bookkeeping logic (3 near-identical blocks) rather than delegating to the shared adapter (`.cross_sectional_visual_display()`) that already exists for exactly this purpose. The existing "no scientific recomputation" regression test only regexes for a few forbidden function names and would not catch this kind of duplicated-logic drift.

**Medium**
- `R/13g-stage-plot-evidence.R:144-146` — a validation check relies on `exists("spectrum_layers", inherits=FALSE)` to detect whether an earlier conditional branch ran, rather than an explicit boolean — fragile implicit-state coupling that would silently stop validating after an unrelated refactor.
- The careful "retain degenerate evidence, explain it in the caption" discipline established by the recent #109 fix (for Stage 1 KDE density degeneracy) has **not** been extended to the structurally identical degenerate case in the loess/isoreg atlas/proposal path (`R/13b-component-interpretation.R:3597-3715`), which still silently drops groups with `< 3` distinct values with no caption note.
- `.new_stage_plot_evidence()` hard-codes a two-element `"stage1"`/`"stage2"` switch dispatch in three separate places — low risk given this is closed legacy scope, but worth a comment justifying the exemption from rule 7.
- Repeated caption-field boilerplate (`sampling_unit`, `threshold` text) copy-pasted identically across all five `visual_evidence` S4 methods.

**Low**
- Several widely-used internal helpers (`.cross_sectional_visual_display()`, `.stage_plot_display_errors()`) carry real scientific-contract responsibility but have no roxygen/`@keywords internal` documentation at all.
- `.stage_plot_display_errors()` (~425 lines, nesting to 5-6 levels) and `.time_course_visual_evidence()` (~310 lines) substantially exceed reasonable length/nesting thresholds — exactly the functions most repeatedly touched by recent feature work, meaning their complexity is actively slowing safe iteration.
- The "no scientific recomputation" regression test is a brittle string-regex check on deparsed function bodies rather than a structural guarantee.

**Health:** A genuinely hot, iteratively-hardened area — the #109 fix, digest-bound staleness checks, and the recomputation regression test all show real discipline. The main debt is architectural (two parallel evidence systems) rather than sloppy, and the degenerate-evidence discipline established for one code path hasn't yet propagated to its structural twin.

---

### 9. Process, governance & tooling debt

**ADR staleness/duplication**
- **`decisions/0020-stage1-component-interpretation-statistical-strategy.md` vs `decisions/0020-stage1-component-interpretation-strategy.md`** — two distinct files share ADR number 0020 with contradictory status (`provisional-accepted; external review remains open` vs `accepted`) and materially different decision content (different estimand names, different section structure). `docs/reviews/adr-0020-expert-review-record.md` still points reviewers at the older, still-provisional file. **This needs to be resolved before another agent cites "ADR 0020" ambiguously** — archive the superseded file into `docs/archive/` with an explicit "superseded by" banner (matching the existing pattern for `docs/archive/adr-0020-r-modeling-frameworks.md`), and fix the stale review-record link.
- 5 of 20 ADRs (25%) remain provisional/reopened; several (0001, 0002, 0015) have been provisional for weeks. Each is tracked against a roadmap issue, but the ADR files themselves don't state that resolution path inline — add a one-line "Resolution path: issue #N" to each.
- ADR status vocabulary has drifted from the four-item list `decisions/README.md` defines (`proposed`/`accepted`/`superseded-by`/`rejected`) to at least 8 distinct strings in practice; ADR 0004 has two contradicting status declarations in the same file.

**ROADMAP vs CLAUDE.md consistency**
- No factual contradiction found as of this audit — both are currently in sync on stage status, issue numbers, and completion claims. However, CLAUDE.md duplicates roadmap-relevant content (the "Stage implementation status" table) with no tooling enforcing continued sync — a duplicated-authority risk worth closing by either having `check-roadmap.py` also assert against CLAUDE.md, or shrinking CLAUDE.md's table to a pointer.

**CI/compliance script status — all pass, confirmed by direct execution**
```
check-adr-coverage.py        → PASS (8 strategies covered)
check-roadmap.py             → PASS (roadmap integrity verified against live GitHub issues)
check-registry-compliance.sh → PASS (no dispatcher anti-patterns found)
scripts/tests (41 tests)     → PASS
```
These are genuinely wired into required CI jobs, not aspirational. One gap: the actual `R CMD check`/`testthat` run is gated behind a `full-check` PR label and does not run on ordinary PRs — meaning a PR could merge to `main` on `lint` checks alone, with test regressions caught only post-merge. **Fix:** consider requiring the `full-check` label automatically when `R/` or `tests/` paths change.

**Repo hygiene**
- Build artifacts (`landscapeR.Rcheck/`, `_site/`, `landscapeR_0.3.0.tar.gz`) and `__pycache__` are all correctly gitignored and untracked — confirmed clean, no action needed.
- `DESCRIPTION`'s `Collate:` field is in exact 1:1 sync with `R/*.R` — confirmed clean.
- `.claude-notes.md` is tracked in git despite its own header claiming "Gitignored — not part of the package" (a stale claim); it also contains a "what to do next" section from 2026-06-27 that duplicates/precedes what ROADMAP.md now owns authoritatively, with no banner marking it superseded.
- `hooks/pre-push` correctly mirrors the CI lint job locally and is installed via `install-hooks.sh`, but neither is mentioned anywhere in README.md or docs/agents/ — undiscoverable to a new contributor.
- `docs/architecture/` contains exactly one file (covering only component-interpretation) against a 20K-line, 37-file `R/` tree — the "owned invariants and dependency direction" layer `docs/README.md` describes this directory as providing exists for only one of ~6 major subsystems.

**Health:** Unusually mature and mostly self-enforcing for a project this size — the one concrete governance defect (duplicate ADR 0020) should be fixed promptly since it actively misleads anyone (human or agent) trying to find the current accepted component-interpretation strategy. Everything else here is discoverability/documentation polish, not active inconsistency.

---

## Cross-cutting themes (appearing in 3+ subsystems)

- **Raw `stop()` instead of typed `landscapeR_validation_error`**: found in `R/19-analysis-specification.R`, `R/13a-plot-theme.R`, and (as crashes rather than stops) `R/12-stage1-hogsvd.R` and `R/15-stage2-kde.R`. This is the single most repeated rule-5 gap across the audit.
- **Hard-coded magic numbers that ADRs say should be config/calibrated**: KDE bandwidth (ADR 0002), component near-tie margin and `< 3L` minimum-sample thresholds (ADR 0020), repeated-time-course minimum observations (ADR 0020), lme4 tolerances. All are *tracked* against future calibration work (#51/#67), but several are uncommented literals scattered across multiple call sites rather than named constants — the drift risk is in the scattering, not the existence of a placeholder.
- **Duplicated "joints" that rule 9 says should be abstracted**: independent vs. repeated time-course (`13c`/`13d`), HO-GSVD averaged vs. prereduced (`12`), cross-sectional vs. independent-time-course bootstrap draws (`13e`), and two parallel typed-evidence systems (`13f`/`13g`).
- **Silent degradation instead of typed failure at real boundaries**: `project_into()`'s layer clamp, `synthetic_potential_control()`'s NaN outputs, external `ks::` calls with no guard, `.time_values_numeric()`'s silent `as.numeric()` coercion, the loess/isoreg degenerate-case gap. This is the "no silent caps" principle from CLAUDE.md, and it is the most concrete, fixable theme in this report.
- **Test coverage gaps concentrated on the highest-stakes code**: the evidence-artifact-producing `execute_stage1_benchmark_full()`, K=1 identifiability (the package's actual shipped configuration), `DecompositionResult` validity branches, and 19 validation error messages in `13e` are all untested despite gating scientific claims.

## What's working well (worth preserving, not just fixing debt)

- Boundary validation (`validate_boundary()`) is structurally enforced, not aspirational, at every Stage 1/2 dispatch point.
- The registry/strategy pattern is used correctly and consistently everywhere it's supposed to be, with only minor, ADR-sanctioned exceptions.
- Stage 0's evidence-artifact pipeline (hash-verified, content-addressed, frozen manifests) is unusually rigorous.
- CI compliance tooling (roadmap/ADR/registry checks) is real, passing, and required — not paper process.
- Recent "no silent caps" fixes (#109, #93) show the team actively hardening exactly the failure mode this report flags as the top cross-cutting theme — the discipline exists, it just hasn't propagated to every analogous case yet.
