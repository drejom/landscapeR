# landscapeR roadmap

**Scheduling authority:** This is the single authoritative run sheet for
landscapeR. It owns package scope, milestone order, dependency gates, and the
next task. GitHub issues specify individual deliverables; ADRs decide algorithms
and architecture; neither independently changes the schedule.

**Roadmap bootstrap:** issue #70 established this document and the
source-document boundary.

**Next task after this change lands:** **#193 refreeze and execute revised K=1
acceptance**, using the completed design and high-dimensional operating maps.

**Current scientific boundary:** reach a reproducible, explicitly exploratory
AML `primary_2018` Stage 1 result—or a structured abstention—without beginning
longitudinal Stage 2 or projecting `supp_2016`.

The roles of issues, ADRs, context, specs, plans, archives, vignettes, and
immutable evidence are defined in [`docs/README.md`](docs/README.md).

---

## How to use this run sheet

When work finishes, do not derive priority from the open-issue list. Use this
order:

1. Complete the current issue and its review/visual-proof obligations.
2. Read **Active milestone** below.
3. Select the first unfinished, dependency-ready item in **Single-agent order**.
4. If multiple agents are deliberately available, use only the named parallel
   lanes; never consume a frozen acceptance set early.
5. If a new result changes sequencing, dependencies, or milestone scope, amend
   this roadmap in the same PR. A new issue or ADR alone does not reorder work.

Statuses used here:

- **active** — inside the current milestone;
- **queued** — expected after the current boundary, at lower detail;
- **conditional** — starts only when its named trigger occurs;
- **parked** — deliberately not on the current path;
- **complete** — landed and retained in the completion ledger.

There is no calendar promise. Scientific gates, not dates, advance milestones.

---

## Package state at the start of this roadmap

### Complete foundations

- Contract-based S4 container, stage boundaries, registry, typed results,
  deterministic RNG, versioned sampling design, analysis specification v1, and
  first-class provenance.
- Cross-sectional Stage 2 KDE/log-density implementation, still
  provisional-accepted pending the complete Stage 0 acceptance ladder.
- Stage 1 heterogeneous-feature v2 evidence run completed with a decisive
  negative result: neither legacy candidate is accepted for genuine K≥2
  multi-omic fitting.
- First-class exactly-one-omic-layer SVD, exact-stationary K=1 calibration
  control, current K=1 visual workflow, and claim-boundary guardrails (#50).
- PR-co-located visual landing proof, current-documentation obligations, and
  immutable-evidence separation (#68).

### Current limitations

- K=1 acceptance protocol v1 is retained as predeclared historical evidence,
  and #177 supersedes it with reviewed protocol v2 on merge. The supported
  sample range remains unresolved until governed phase B1 execution and later
  aggregation use the post-merge v2 manifest.
- Cross-sectional component interpretation supports binary, continuous, ordered,
  unordered-descriptive, nuisance-adjusted, resampled, and search-aware
  permutation evidence. Independent destructive and repeated-subject
  time-course paths are implemented through registered strategies.
- Prepared AML time/cohort lineage is corrected by #53; generated objects
  remain local because raw GEO data are not tracked.
- The descriptive component gallery is corrected by #54 on merge; the
  sampling-design-aware atlas/proposal/confirmation workflow remains #55.
- No K≥2 production decomposition strategy is accepted.
- Longitudinal Stage 2 and 2D/bifurcation Stage 2 are research/ADR work only.
- No curated or evidentiary AML, diabetes, or Pogona biological claim is
  currently supported.

---

# Active milestone — exploratory AML `primary_2018` Stage 1

## Exit boundary

The milestone is complete only when:

1. the K=1 workflow has passed its frozen independent generic and synchronized
   AML-shaped synthetic controls, then demonstrated its failure boundary under
   asynchronous AML manifestation;
2. a complete AnalysisSpecification v2 retains target intent and a confirmed
   component decision;
3. the AML state-space is fitted on `primary_2018` only;
4. descriptive component/metadata evidence precedes proposal and human
   confirmation;
5. the result is either an exploratory target biological axis with stability
   evidence or a structured abstention;
6. repeated AML observations are not passed to the cross-sectional Stage 2
   estimator; and
7. no `supp_2016` observation has refitted, reranked, or altered the primary
   state-space.

## Dependency shape

```text
#61 AnalysisSpecification v2 ───────────────┐
#53 authoritative decimal weeks ───────────┼─> #55 atlas/proposal/confirmation
#54 component-gallery repair ──────────────┘             │
                                                         v
                                             #67 implementation/calibration
                                                         │
                                                         v
                                             #51 phase A: freeze protocol +
                                                  seed derivation
                                                         │
                                                         v
                                             #177 protocol v2: lower tail +
                                                  missing-cell safety
                                                         │
                                                         v
                                             #51 phase B1: generic + negatives
                                                         │
                                                         v
                                             #67 independent acceptance execution
                                                  complete negative result
                                                         │
                                                         v
                                             #187 revised calibration spec
                                                         │
                                                         v
                                             #188 canonical recovery gate +
                                                  typed outcome states
                                                         │
                                      ┌──────────────────┼──────────────────┐
                                      v                  v                  v
                              #189 destructive     #190 repeated      #191 signal/noise
                              sampling map         sampling map        regimes
                                      └──────────────────┼──────────────────┘
                                                         v
                                             #193 refreeze + independent
                                                  acceptance execution
                                                         │
                                                         v
                                             #51 phase B: aggregate/finalize
                                                         │
                                                         v
                                             #168 asynchronous-onset robustness
                                                         │
                                                         v
                                             #71 exploratory AML Stage 1
```

#51 and #67 crossed at the original calibration/acceptance boundary: #67 used
only seeds and rules already frozen by #51. That completed negative result is
now immutable historical evidence. The same separation applies to #187–#193:
disclosed calibration may design the revision, but newly frozen independent
seeds alone may evaluate it.

## Single-agent order

### 1. Analysis intent and confirmation lifecycle — #61 (complete)

**Deliverable:** AnalysisSpecification v2 retains the complete target
declaration and adds `selected_component`, proposal digest, accept/override
status, rationale, lifecycle validity, canonical digest, provenance, and an
explicit v1 migration that never fabricates missing target intent.

**Exit:** all v1/v2 boundary, migration, digest, and no-fallback tests pass; #55
can return a confirmed v2 specification.

### 2. Authoritative AML observation time and cohort identity — #53 (complete)

**Deliverable:** correct the reversed 2018/2016 prepared layers, preserve the
source `sample_weeks` values exactly, declare only `mouse_id` and
`sample_weeks` as longitudinal structure, and record immutable source/mapping
provenance without inventing endpoint/event semantics.

**Exit:** all 233 retained observations map one-to-one to verified numeric time;
`primary_2018` is the 132-observation source-paper training cohort and
`supp_2016` is the 101-observation source-paper validation cohort 1; no
categorical-label parsing or guessed time exists.

### 3. Human-readable component gallery — #54 (complete on merge)

**Deliverable:** canonical MAE-level metadata/sample alignment, categorical and
continuous colour rendering, corrected title, typed missing/ambiguous metadata
failure, and before/after visual proof.

**Exit:** plots faithfully render descriptive evidence but own no scientific
association score or ranking.

### 4. Component interpretation workflow — #55

**Decision gate complete:** ADR 0020 is accepted. It governs cross-sectional
and longitudinal associations, adjustment, biological-unit uncertainty,
multiplicity, minimum data, abstention, axis identifiability, visual decision
surfaces, and the explicit human-confirmation boundary.

**Deliverable:** MetadataAssociationAtlas → ComponentProposal → human
confirmation, with raw and adjusted evidence separately visible and sampling
design respected.

**Implementation slices:** #79 establishes the cross-sectional binary tracer
path; #80, #81, and #82 then add adjusted/general cross-sectional, independent
destructive-time-course, and repeated-subject interpretation respectively;
#91 deepens the shared interpretation/evidence seam before #83 integrates
evidence-tier axis identifiability across the completed paths. #92 then moves
both time-course adapters behind that seam. #93 and #94 are follow-on
resampling-policy and typed visual-evidence deepening slices; they do not
silently expand #83.
The reusable publication visual grammar and 100 mm export helper are the
cross-cutting visual prefactor for #79; they expose later decision surfaces
consistently but do not themselves satisfy #79's scientific exit.

**Exit:** synthetic truth can assert proposals; real data always requires human
confirmation; stable-subspace/no-stable-axis is a valid abstention.

### 4a. Architecture debt lane

**Active prefactor:** #91 and its general-contract correction #100 are
complete. #92, #83, #93, #94, #106, and #108 are complete. #107 completes on
merge, closing the public scientific-caption migration and returning the active
sequence to the K=1 calibration lane. #114 completes on merge, moving the
legacy Stage 1/2 plot calculations behind stored typed evidence without
reordering that lane.
#101 reconciles supporting Pogona manifests without changing the active task
sequence. With #93 complete on merge, the plot audit recorded in #106–#109
resumes: #106 is the caption-contract prefactor for the queued #94
visual-evidence view and the #107/#108 renderer migrations.

**Parked debt:** #95 deepens stage completion/provenance. #96 establishes shared
artifact migration policy, with #97 adopting it across the interpretation
evidence graph. These issues remain parked until the active #55/#83
interpretation lane lands.

### 4b. Audited architecture, correctness, and execution backlog

The [2026-07-31 whole-codebase technical-debt audit](docs/archive/technical-debt-audit-2026-07-31.md)
and follow-up architecture and HPC reviews are fully represented by issues.
The maintenance lane is deliberately active until the audited backlog is clean.
The K=1 acceptance ladder remains the current scientific lane. #51 phase B1
executed all 16,100 frozen generic, negative-control, and shared-baseline tasks,
and #67 executed all 900 frozen AML-shaped tasks. Neither run supports a sample
range. The #67 audit also showed that the validation instrument itself is not
yet fit for final adjudication: it gates one-dimensional recovery twice using
inconsistent cosine/angle cutoffs, cannot evaluate some declared small-sample
cells, assumes complete repeated trajectories, and tests only one
fixed-total-signal high-dimensional regime. The next task is #188, followed by
the revised calibration sequence in #189–#191 and a newly frozen independent
acceptance in #193. Issue labels do not independently change this schedule.

**Deterministic maintenance-loop order:** when this lane is deliberately
opened, process one issue through implementation, both review modes, green CI,
and merge before starting the next:

1. review-memory prerequisite: #138;
2. correctness and safety foundations: #119, #120, #121, #122, #123, #124,
   #125, #126, #128, #129, #130;
3. shared future execution and association migration: #57 and #132 complete;
4. deep scientific modules: #117, #118, #127;
5. remaining Stage 1 execution migration: #133;
6. contributor/architecture documentation after its owners stabilize: #131;
7. remote execution and production orchestration: #134, then #135.

Closed issues are skipped. If an issue becomes blocked, record the blocker in
its roadmap row and stop the loop rather than silently selecting a later item.
The loop never merges with unresolved review threads or failing required
checks. Each pull request must also wait for the actual GitHub Copilot review;
actionable comments are fixed and evidentially incorrect findings are declined
before every thread is resolved. After the maintenance loop is clean, stop for
human confirmation before restoring the AML acceptance sequence as the
repository's next task.

**Review memory:** #138 established the incident-backed Ratchet Principle before
the audited backlog proceeded, so review knowledge earned by #119 onward remains
available to later cold-start agents. #119 through #122 have landed. #144 is a
stop-the-line documentation-toolchain investigation opened from the #122 merge
evidence; resolve it before returning to the ordered maintenance lane at #123.

**Scientific correctness and safety:** #119 centralizes the ADR-declared Holm
correction; #120 protects registry identity; #121 hardens the legacy HO-GSVD
adapters; #122 validates Stage 0 potential controls and sweep accounting; #123
makes KDE bandwidth and failures explicit; #124 normalizes typed public
validation; #125 tests complete Stage 1 artifact publication; #126 covers the
accepted K=1 identifiability regime; #127 strengthens core construction and
provenance, including the repeated `DecompositionResult` accessor guards; and
#128 restores the canonical publication palette. Projection
identity, layer bounds, and discovery-fitted transforms remain owned by the
existing AML robustness issue #24 rather than a duplicate audit issue.

**Deep-module architecture:** #117 deepens registered association strategies
and normalized evidence, covering the component-interpretation monolith,
time-course duplication, diagnostics, model controls, and multiplicity seams.
#118 unifies the parallel typed visual-evidence systems and total display
preparation. Existing parked #95–#97 continue to own stage completion,
provenance, and artifact/evidence migration policy.

**Governance and contributor safeguards:** #129 resolves duplicate ADR
authority and status drift; #130 makes package-test selection automatic for
source-affecting changes; #131 removes duplicated repository authorities and
documents hook and subsystem safeguards. Repository hygiene and ephemeral
artifacts are handled by a separate reviewed cross-cutting decision and
enforcement change rather than a scheduled implementation issue in this PR.

**Scalable execution:** #57 is the future-backed repetition and run-level RNG
prefactor. #132 migrates association bootstrap/permutation workloads and #133
migrates Stage 1 summary bootstraps. Once both are complete, #134 validates
remote workers and the Gadi deployment contract; #135 then adds
`targets`/`crew` scheduler-backed full-evidence orchestration. Package code
does not choose a future plan, and sequential execution remains the default
backend through the same future seam.

| Audit/review theme | Authoritative backlog |
|---|---|
| Association strategy depth, duplicated time-course logic, multiplicity | #117, #119 |
| Typed visual evidence, display totality, publication palette | #118, #128 |
| Registry and legacy decomposition safety | #120, #121 |
| Stage 0 controls, Stage 2 KDE, typed public boundaries | #122, #123, #124 |
| Stage 1 publication and K=1 identifiability coverage | #125, #126 |
| Core construction, provenance, stage completion and migration | #127, #95, #96, #97 |
| Projection invariants and AML discovery/validation separation | #24 |
| ADR authority, CI selection, contributor/repository governance | #129, #130, #131; separate repository-hygiene decision |
| Future-backed repetition, deterministic RNG, HPC and orchestration | #57, #132, #133, #134, #135 |

### 5. AML-shaped synthetic control — #67 complete negative acceptance

**Deliverable:** repeated synthetic mice, stronger time/nuisance axis, planted
non-dominant condition-by-time target axis, subject-aware atlas/proposal,
component alignment, and typed cross-sectional Stage 2 ineligibility.

**Calibration only:** develop and diagnose on disclosed seeds. Do not consume
the independent acceptance seeds.

**Status:** complete. All 900 frozen tasks executed on Gemini and the verified
content-addressed artifact
`k1-stage0-acceptance-v2-728dc79c448d7e42` preserves the original worker
results and separate recovery-collector provenance. No cell passed every frozen
cell-level criterion. At 100 features, replicate pass rates were 0%, 50%, and
96% for 4, 7, and 12 mice per condition; all 1,000- and 10,000-feature cells
had 0% complete replicate passes.

**Interpretation boundary:** this is a valid negative acceptance result, but it
does not establish that the scientific method is unfit. Audit showed that the
1,000-feature planted axis was recovered closely while failing a redundant
15-degree cutoff, four-mouse cells could not produce the required
identifiability evidence, and the 10,000-feature fixed spike was submerged by
an increasing independent-noise spectrum. The artifact and consumed seeds
remain immutable historical evidence.

### 6. Refreeze K=1 acceptance before execution: #51 phase A and #177

**Deliverable:** predeclare generic recovery/thinness/negative controls, #67
metrics, false-positive limits, pass-rate rules, supported-range rule, and
hidden disjoint acceptance seeds in a content-addressed protocol.

**Exit:** protocol identity is immutable before any acceptance aggregation.

**Status:** protocol v1 completed phase A without executing an acceptance seed.
On merge, #177 retains v1 as historical evidence and publishes protocol v2 with
matching generic positive and negative grids over
`n = 8, 12, 16, 24, 48, 96, 132, 192`, the existing omics-scale feature grid,
and a shared-baseline missing-cell safety control whose expected result is typed
abstention. No v1 or v2 production seed is derived before the reviewed v2 merge
commit. Phase B1 subsequently executed from that reviewed merge.

**Phase-B1 result:** all 16,100 requested tasks are present in verified artifact
`k1-stage0-acceptance-v2-780f4b10ea21923a`. No generic cell reached the frozen
90% pass-rate gate, and false double-well topology exceeded the frozen 5%
maximum in both negative controls. False target selection stayed within the
limit, and the shared-baseline safety control passed. The supported minimum is
therefore `NA`. #67 subsequently completed with a negative result, but the
combined evidence exposed validation-instrument defects now governed by
#187–#193; ADR 0002 is not amended from these historical runs.

### 7. Repair the K=1 calibration instrument — #187 and #188

**Parent specification:** #187 defines the design-aware calibration and
operating-map contract. #188 is complete on merge: it corrects the duplicated
one-dimensional recovery gate and introduces typed outcomes that distinguish
recovery failure, downstream non-estimability, evaluated threshold failure,
and execution failure.

**Exit:** one governed calibration path exposes the corrected semantics through
replicate evidence, aggregation, operating-map-ready data, scientific caption,
artifact provenance, and visual proof without rewriting #67.

### 8. Map realistic designs and high-dimensional regimes — #189–#191

After #188, three independently grabbable slices may proceed in parallel. The
single-agent run order starts with #189:

- #189 maps independent destructive time courses with one to three biological
  samples per condition-time cell, unequal cells, isolated sequencing loss,
  and missing internal cells;
- #190 maps complete and incomplete repeated-subject trajectories, retaining
  strict typed random-slope abstention; and
- #191 separates fixed-spike adversarial noise, sparse informative features,
  growing coherent signal, correlated modules, and null/near-null regimes above,
  near, and below the recovery boundary.

Each slice must deliver a complete governed path through generation, execution,
typed evidence, operating map, separate caption, artifact, and visual proof.

### 9. Refreeze and execute revised K=1 acceptance — #193 then #51 phase B

After #189–#191, review the disclosed calibration evidence, amend ADRs 0016 and
0002, freeze a new protocol with entirely disjoint seeds, and execute #193.
Then #51 may integrate the historical and revised artifacts and state supported,
unsupported, and out-of-domain regions. A negative result remains valid; the
same seeds may not tune and validate a revision.

#192, which locates a real experiment as a point or uncertainty region within a
compatible calibrated operating domain, is useful but does not block #193.

### 10. Asynchronous-onset AML robustness control — #168

**Deliverable:** retain approximately stationary CTL trajectories while AML
animals move coherently along a planted disease direction at heterogeneous
latent onset times, including non-manifesting animals within the observation
window. Exercise step-like, sigmoid, and gradual transitions across onset
dispersion, responder fraction, effect strength, irregular sampling, and
design-preserving dropout.

**Claim boundary:** this is a known-truth robustness gate, not independent
biological acceptance. It follows revised acceptance #193 and #51 phase B so it
cannot redefine thresholds from its own output. A calibrated structured
abstention is a valid result where the asynchronous signal is not recoverable.

### 11. Exploratory primary AML Stage 1 — #71

Fit `primary_2018` only, show the observation-before-interpretation sequence,
require human component confirmation, freeze the state-space definition, and
record either an exploratory result or a structured abstention. This is the
milestone boundary—not a longitudinal Stage 2 result or confirmatory biological
claim.

## Named parallel lanes

- #53 and #54 may run while #61 is implemented.
- ADR 0020 is accepted and the #61 v2 lifecycle seam is complete; #55
  association implementation may proceed.
- #60 may locate/verify cKit, blast, or flow metadata at any time; it is useful
  atlas enrichment but does not block the primary target/time analysis.
- #168 must not run before #193 and #51 phase B complete. It is the final
  synthetic realism gate before #71, not another calibration source for frozen
  thresholds.
- The verified execution audit has satisfied #57's reusable-repetition trigger.
  #57 is agent-ready as a deliberately opened parallel maintenance prefactor;
  it does not displace #188 or justify rewriting stable numerical code.
- #172 may run now as a human-led documentation-standards and audit lane while
  #177 corrects the protocol and the later #51 execution proceeds. It does not
  consume acceptance seeds or displace the scientific next task.
- #178 may research a future baseline-anchored shared-control estimand without
  changing the current missing-cell abstention. It does not block #177, #51, or
  the AML milestone.

## Cross-cutting documentation clarity lane

This lane starts during the active AML milestone rather than waiting for a
generic productisation phase. It preserves the current technical record while
adding a concept-first path for bioinformaticians and future contributors. It
must not simplify away mathematical definitions, uncertainty, abstention,
claim boundaries, or reproducibility contracts.

The sequence is:

1. #172 defines the audience-specific standard through human grilling and
   audits representative documentation. This work is active now and may run in
   parallel with the #187–#193 calibration lane.
2. #173 applies the approved standard to the complete K=1 acceptance journey.
   It must land before #51 phase B publishes the revised supported operating
   range, so the final K=1 conclusion uses the agreed explanatory structure.
3. #174 establishes the canonical contributor path after #172. It does not
   block #188–#193, #168, or #71, but it must complete before v1 or before the
   project solicits implementation of new modules from external contributors,
   whichever comes first.
4. #175 automates only mechanically safe requirements after #172 and the #173
   pilot. It is a pre-v1 gate and must leave scientific clarity and appropriate
   technical depth as review judgments.

The #172 audit may create additional issues grouped by scientific journey and
root cause. Each new issue must be placed explicitly in this roadmap. Material
gaps in a public workflow must be corrected before that workflow becomes part
of the v1 surface; the audit must not become an uncontrolled package-wide
rewrite.

---

# Queued milestone — AML robustness projection

**Forecast resolution:** medium. Revisit in detail only after #71.

Likely sequence:

1. Complete #24 invariant safety: canonical sample/feature identity,
   discovery-fitted centring/scaling, layer-specific loadings, typed projection
   failures, and permutation/recovery controls.
2. Project `supp_2016` into the immutable `primary_2018` basis as a hostile
   batch/time-confounded stress test. It cannot refit, rerank, or confirm the
   discovery choice.
3. Consider #22 only after complete-cohort projection is safe and predeclared
   missingness controls justify projection-only handling of incomplete omic
   observations.

A dedicated `supp_2016` projection execution issue should be created at the #71
boundary; it is intentionally not specified before the primary state-space
exists.

---

# Likely scientific path after AML Stage 1

The current forecast is AML longitudinal dynamics, because it builds directly
on the frozen K=1 AML state-space. The boundary review after robustness
projection may reorder this against the independent K≥2/diabetes lane, but must
amend this roadmap explicitly.

## Longitudinal AML Stage 2

**Forecast resolution:** medium-to-low.

1. #62: research maintained longitudinal drift/diffusion methods, define
   candidates/criteria, write the ADR, and specify estimator-only plus AML-shaped
   trajectory controls. The first target remains one common static 1D landscape,
   estimated constant diffusion, and barrier first-passage time.
2. #66: add optional verified event/censoring declarations only when source
   semantics are known; event termination remains distinct from barrier crossing
   and disease onset.
3. Implement and accept the common-landscape strategy only after its frozen
   synthetic trajectory ladder.
4. Keep #63, #64, and #65 parked until the common-landscape baseline is accepted;
   they are separate estimands, not toggles.

## K≥2 multi-omic / islet-diabetes lane

**Forecast resolution:** low.

1. #49: reconcile ADR 0015 terminology and incompatible thresholds, define new
   candidates before results, freeze a rank-deficiency-aware v3 protocol, and
   execute independent comparison.
2. Create explicit issues for diabetes data manifest/preparation, accepted K≥2
   state-space fitting, and real-data applicability only after v3 accepts a
   strategy.
3. Genotype rank deficiency remains a mandatory Stage 0 axis; legacy
   `hogsvd_averaged`/block-scaled results are not an accepted baseline.

---

# Later scientific lane — Pogona and multi-axis Stage 2

**Forecast resolution:** low.

- #59 owns the general stable-subspace/no-stable-axis and future 2D Stage 2
  capability. It requires its own topology classes, controls, metrics, and
  observation-before-interpretation surfaces.
- #52 owns the Pogona-specific bifurcation topology control and estimator ADR.
  A generic 2D estimator is not automatically a valid bifurcation estimator.
- Pogona real data remains blocked until both dimensionality and
  topology-specific synthetic gates pass.

---

# Productisation and conditional infrastructure

These items do not reorder the scientific path unless their trigger is met:

- #57 — future-backed repetition, compute tiers, and run-level RNG; retained as
  the completed execution prefactor for #132–#135 and the revised calibration
  workloads.
- #41 — development-only SSH adapter, triggered only by a frozen run that
  cannot be completed on the available local executor.
- #58 — focused tidy accessors/interoperability after scientific result
  contracts stabilize.
- #56 — Shiny orchestration only after package-owned atlas/proposal/specification
  APIs and claim gates stabilize.
- #5 — consolidate or unexport deferred Stage 0.5/0.75 stubs when the public API
  cleanup lane is opened or the first real implementation begins.
- #170 — split the K=1 acceptance runner along manifest, execution, artifact,
  and orchestration seams after the governed acceptance run, without changing
  its scientific or artifact contracts.
- #178: decide whether to support a baseline-anchored shared-control time-course
  estimand. It is parked human-led research and cannot weaken the current typed
  missing-cell abstention or delay the K=1 acceptance ladder.

These capabilities must not become alternate scientific implementations or
bypass Stage 0 gates.

---

# Canonical roadmap issue register

This register maps every open issue to exactly one roadmap lane. Completed
bootstrap rows may remain when they explain the roadmap itself. Detailed issue
bodies may state dependencies but do not change this ordering.

<!-- issue-map:start -->
| Issue | Roadmap lane | State |
|---|---|---|
| [#5](https://github.com/drejom/landscapeR/issues/5) | Productisation/API cleanup | parked |
| [#22](https://github.com/drejom/landscapeR/issues/22) | AML robustness projection | queued |
| [#24](https://github.com/drejom/landscapeR/issues/24) | AML robustness projection | queued |
| [#41](https://github.com/drejom/landscapeR/issues/41) | Conditional infrastructure | conditional |
| [#49](https://github.com/drejom/landscapeR/issues/49) | K≥2/islet-diabetes | queued |
| [#51](https://github.com/drejom/landscapeR/issues/51) | Exploratory AML Stage 1 gate | active — historical runs complete; final aggregate after #193 |
| [#52](https://github.com/drejom/landscapeR/issues/52) | Pogona/bifurcation | queued |
| [#53](https://github.com/drejom/landscapeR/issues/53) | Exploratory AML Stage 1 foundation | complete |
| [#54](https://github.com/drejom/landscapeR/issues/54) | Exploratory AML Stage 1 foundation | complete on merge |
| [#55](https://github.com/drejom/landscapeR/issues/55) | Exploratory AML Stage 1 interpretation | active — parent lane |
| [#56](https://github.com/drejom/landscapeR/issues/56) | Productisation/Shiny | parked |
| [#57](https://github.com/drejom/landscapeR/issues/57) | Execution scalability — futures/RNG prefactor | complete on merge |
| [#58](https://github.com/drejom/landscapeR/issues/58) | Productisation/tidy interface | parked |
| [#59](https://github.com/drejom/landscapeR/issues/59) | General multi-axis Stage 2 | queued |
| [#60](https://github.com/drejom/landscapeR/issues/60) | Optional AML metadata enrichment | active, non-blocking |
| [#61](https://github.com/drejom/landscapeR/issues/61) | Exploratory AML Stage 1 foundation | complete |
| [#62](https://github.com/drejom/landscapeR/issues/62) | Longitudinal AML Stage 2 | queued |
| [#63](https://github.com/drejom/landscapeR/issues/63) | Longitudinal extensions | parked |
| [#64](https://github.com/drejom/landscapeR/issues/64) | Longitudinal extensions | parked |
| [#65](https://github.com/drejom/landscapeR/issues/65) | Longitudinal extensions | parked |
| [#66](https://github.com/drejom/landscapeR/issues/66) | Longitudinal observation design | queued |
| [#67](https://github.com/drejom/landscapeR/issues/67) | Exploratory AML Stage 1 acceptance | complete — verified negative result; validation-design limits exposed |
| [#70](https://github.com/drejom/landscapeR/issues/70) | Roadmap/documentation bootstrap | complete |
| [#71](https://github.com/drejom/landscapeR/issues/71) | Exploratory AML Stage 1 execution | active — milestone exit |
| [#79](https://github.com/drejom/landscapeR/issues/79) | Exploratory AML Stage 1 interpretation — #55 slice | complete |
| [#80](https://github.com/drejom/landscapeR/issues/80) | Exploratory AML Stage 1 interpretation — #55 slice | complete |
| [#81](https://github.com/drejom/landscapeR/issues/81) | Exploratory AML Stage 1 interpretation — #55 slice | complete |
| [#82](https://github.com/drejom/landscapeR/issues/82) | Exploratory AML Stage 1 interpretation — #55 slice | complete |
| [#83](https://github.com/drejom/landscapeR/issues/83) | Exploratory AML Stage 1 interpretation — #55 integration | complete on merge |
| [#91](https://github.com/drejom/landscapeR/issues/91) | Interpretation evidence architecture prefactor | complete on merge |
| [#92](https://github.com/drejom/landscapeR/issues/92) | Time-course interpretation architecture migration | complete on merge |
| [#93](https://github.com/drejom/landscapeR/issues/93) | Design-preserving resampling policy | complete on merge |
| [#94](https://github.com/drejom/landscapeR/issues/94) | Typed visual-evidence view | complete on merge |
| [#95](https://github.com/drejom/landscapeR/issues/95) | Stage completion and provenance architecture | parked |
| [#96](https://github.com/drejom/landscapeR/issues/96) | Shared artifact migration policy | parked |
| [#97](https://github.com/drejom/landscapeR/issues/97) | Interpretation evidence-graph migration policy | parked — blocked by #96 |
| [#100](https://github.com/drejom/landscapeR/issues/100) | Shared interpretation evidence contract correction | complete on merge |
| [#101](https://github.com/drejom/landscapeR/issues/101) | Pogona master-registry manifest reconciliation | complete |
| [#104](https://github.com/drejom/landscapeR/issues/104) | Candidate temporal biological dataset | parked — research question |
| [#106](https://github.com/drejom/landscapeR/issues/106) | Scientific caption contract — visual-evidence prefactor | complete on merge |
| [#107](https://github.com/drejom/landscapeR/issues/107) | Stage 1/2 scientific caption migration | complete on merge |
| [#108](https://github.com/drejom/landscapeR/issues/108) | Component-interpretation caption migration | complete on merge with #94 |
| [#109](https://github.com/drejom/landscapeR/issues/109) | Component-identifiability primary/diagnostic views | complete on merge |
| [#114](https://github.com/drejom/landscapeR/issues/114) | Legacy Stage 1/2 typed plot evidence | complete on merge |
| [#117](https://github.com/drejom/landscapeR/issues/117) | Audited architecture — association strategy and evidence | complete on merge |
| [#118](https://github.com/drejom/landscapeR/issues/118) | Audited architecture — typed visual evidence | complete on merge |
| [#119](https://github.com/drejom/landscapeR/issues/119) | Audited correctness — multiplicity | complete on merge |
| [#120](https://github.com/drejom/landscapeR/issues/120) | Audited integrity — strategy registry | complete on merge |
| [#121](https://github.com/drejom/landscapeR/issues/121) | Audited safety — legacy HO-GSVD | complete on merge |
| [#122](https://github.com/drejom/landscapeR/issues/122) | Audited safety — Stage 0 controls | complete on merge |
| [#123](https://github.com/drejom/landscapeR/issues/123) | Audited safety — Stage 2 KDE | complete |
| [#124](https://github.com/drejom/landscapeR/issues/124) | Audited safety — typed public validation | complete |
| [#125](https://github.com/drejom/landscapeR/issues/125) | Audited assurance — Stage 1 artifact publication | complete |
| [#126](https://github.com/drejom/landscapeR/issues/126) | Audited assurance — K=1 identifiability | complete on merge; then resume #128 |
| [#127](https://github.com/drejom/landscapeR/issues/127) | Audited architecture — core construction and provenance | complete on merge |
| [#128](https://github.com/drejom/landscapeR/issues/128) | Audited visual grammar — canonical palette | complete |
| [#129](https://github.com/drejom/landscapeR/issues/129) | Audited governance — ADR authority | complete |
| [#130](https://github.com/drejom/landscapeR/issues/130) | Audited CI — package-test selection | complete |
| [#131](https://github.com/drejom/landscapeR/issues/131) | Audited governance — contributor safeguards | complete on merge |
| [#132](https://github.com/drejom/landscapeR/issues/132) | Execution scalability — association futures migration | complete |
| [#133](https://github.com/drejom/landscapeR/issues/133) | Execution scalability — Stage 1 futures migration | complete |
| [#134](https://github.com/drejom/landscapeR/issues/134) | Execution scalability — remote workers and Gadi | complete |
| [#135](https://github.com/drejom/landscapeR/issues/135) | Execution scalability — scheduler orchestration | complete on merge |
| [#138](https://github.com/drejom/landscapeR/issues/138) | Cross-cutting governance — incident-backed review ratchet | complete |
| [#144](https://github.com/drejom/landscapeR/issues/144) | Maintenance — pkgdown stack-imbalance warnings | complete on merge; then resume #123 |
| [#158](https://github.com/drejom/landscapeR/issues/158) | Candidate decomposition method — rhoPCA | parked — research question |
| [#159](https://github.com/drejom/landscapeR/issues/159) | Candidate temporal biological dataset — snake brumation | parked — research question |
| [#168](https://github.com/drejom/landscapeR/issues/168) | Exploratory AML Stage 1 — asynchronous-onset robustness | active — blocked by #193 and #51 phase B |
| [#170](https://github.com/drejom/landscapeR/issues/170) | Maintenance — K=1 acceptance runner module seams | queued after governed #51 execution |
| [#172](https://github.com/drejom/landscapeR/issues/172) | Cross-cutting documentation clarity: standard and audit | active; parallel human decision lane |
| [#173](https://github.com/drejom/landscapeR/issues/173) | Cross-cutting documentation clarity: K=1 pilot | queued; blocked by #172; before #51 phase B publication |
| [#174](https://github.com/drejom/landscapeR/issues/174) | Productisation: contributor module path | queued; blocked by #172; pre-v1 gate |
| [#175](https://github.com/drejom/landscapeR/issues/175) | Cross-cutting documentation clarity: mechanical enforcement | queued; blocked by #172 and #173; pre-v1 gate |
| [#177](https://github.com/drejom/landscapeR/issues/177) | Exploratory AML Stage 1 gate: K=1 protocol v2 | complete on merge; then #51 phase B1 |
| [#178](https://github.com/drejom/landscapeR/issues/178) | Independent time-course extension: shared baseline controls | parked; human method decision; non-blocking |
| [#181](https://github.com/drejom/landscapeR/issues/181) | Maintenance — R lint baseline and ratcheting enforcement | queued; standalone maintenance lane |
| [#187](https://github.com/drejom/landscapeR/issues/187) | K=1 design-aware calibration and operating maps | active — parent specification |
| [#188](https://github.com/drejom/landscapeR/issues/188) | K=1 calibration semantics | complete |
| [#189](https://github.com/drejom/landscapeR/issues/189) | K=1 destructive-time-course operating map | complete on merge |
| [#190](https://github.com/drejom/landscapeR/issues/190) | K=1 repeated-subject operating map | complete on merge |
| [#191](https://github.com/drejom/landscapeR/issues/191) | K=1 high-dimensional signal regimes | complete on merge; then #193 |
| [#192](https://github.com/drejom/landscapeR/issues/192) | K=1 real-experiment operating-domain locator | queued — blocked by #189–#191; does not block acceptance |
| [#193](https://github.com/drejom/landscapeR/issues/193) | K=1 revised independent acceptance | active — next |
| [#198](https://github.com/drejom/landscapeR/issues/198) | Maintenance — shared K=1 calibration publication seams | queued before another calibration module; does not block #191 or #193 |
<!-- issue-map:end -->

---

# Completion ledger

Move milestone outcomes here when they land; do not delete the evidence trail.
Issue-level implementation details remain in closed issues, PRs, and archived
plans.

| Date | Outcome | Evidence/status |
|---|---|---|
| 2026-07-13 | Stage 1 heterogeneous v2 evidence | Complete negative result; no K≥2 strategy accepted |
| 2026-07-14 | K=1 SVD foundation | #50 complete; disclosed calibration only |
| 2026-07-14 | Visual landing-proof workflow | #68 complete; PR is canonical transition proof |
| 2026-07-14 | AnalysisSpecification v2 lifecycle | #61 complete; target intent retained through confirmation |
| 2026-07-14 | AML observation-time and cohort lineage | #53 complete; exact source weeks and corrected 2018/2016 roles |
| 2026-07-25 | Independent destructive-time-course interpretation | #81 complete on merge; registered fixed-effects strategy, design-preserving evidence, and typed abstention |
| 2026-07-26 | Repeated-subject time-course interpretation | #82 complete on merge; registered correlated random-slope strategy, whole-trajectory evidence, and typed abstention |
| 2026-07-15 | Descriptive component gallery | #54 complete on merge; canonical metadata colour without private ranking |
| 2026-07-24 | Component-interpretation statistical strategy | ADR 0020 accepted; #55 implementation gate open |
| 2026-07-25 | General cross-sectional component interpretation | #80 complete; continuous, ordered, adjusted, resampled, and search-aware evidence landed |
| 2026-07-27 | Pogona master-registry reconciliation | #101 complete; canonical manifests derive from the audited registry while unresolved records remain excluded |
| 2026-08-06 | Durable evidence execution substrate | #132–#135 complete on merge; future-backed repetition, remote-worker identity, transfer benchmarking, and targets/crew scheduler orchestration retain one scientific interface |
| 2026-08-12 | Frozen AML-shaped K=1 acceptance | #67 complete negative result; 900/900 tasks verified, no supported cell, and validation-instrument defects routed to #187–#193 without reusing consumed seeds |

---

# Change control

Update this roadmap in the same PR when any of these changes:

- the next task;
- issue dependency or blocking status;
- active milestone entry/exit criteria;
- movement between active, queued, conditional, parked, or complete;
- creation/closure of an issue represented in the canonical roadmap register;
- evidence that changes the likely package path.

A PR that closes the current task anticipates merge: mark that row `complete on
merge` and advance exactly one other row/declaration to **next** in the same PR.
The checker accepts the completion row both before and after GitHub closes the
issue, so the pull-request and post-merge runs remain deterministic.

Do not update the roadmap merely to repeat implementation detail already present
in an issue or ADR. Keep near-term detail high and later detail intentionally
lower. At each milestone boundary, expand only the next selected milestone and
retain later lanes as sketches until their decisions are due.
