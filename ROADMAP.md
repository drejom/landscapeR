# landscapeR roadmap

**Scheduling authority:** This is the single authoritative run sheet for
landscapeR. It owns package scope, milestone order, dependency gates, and the
next task. GitHub issues specify individual deliverables; ADRs decide algorithms
and architecture; neither independently changes the schedule.

**Roadmap bootstrap:** issue #70 established this document and the
source-document boundary.

**Next task after this change lands:** **#55 — component interpretation workflow**.

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

- No K=1 acceptance thresholds or supported sample range are final.
- No sampling-design-aware component atlas/proposal/confirmation implementation
  exists.
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

1. the K=1 workflow has passed its frozen independent generic and AML-shaped
   synthetic controls;
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
                                             #51 phase A: freeze protocol + seeds
                                                         │
                                                         v
                                             #67 independent acceptance execution
                                                         │
                                                         v
                                             #51 phase B: aggregate/finalize
                                                         │
                                                         v
                                             #71 exploratory AML Stage 1
```

#51 and #67 deliberately cross at the calibration/acceptance boundary: #67 may
be implemented and exercised on disclosed calibration seeds, but its independent
acceptance run uses only seeds and rules already frozen by #51. The same output
cannot choose and validate the protocol.

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

**Decision gate first:** write and accept the statistical-strategy ADR covering
independent cross-sectional, independent time-course, and repeated-subject
associations, adjustment, biological-unit
uncertainty, multiplicity, structural identifiability, empirically derived
supported ranges, and abstention before implementation. Numeric support limits
come from synthetic sweeps rather than rule-of-thumb minima. Before acceptance,
obtain lightweight external expert review with a versioned instrument, preserve
responses and substantive dissent privately, and resolve or explicitly retain
all implementation-blocking objections. Feedback is not published or quoted
without separate permission, and non-response is not agreement.

**Deliverable:** MetadataAssociationAtlas → ComponentProposal → human
confirmation, with raw and adjusted evidence separately visible and sampling
design respected.

**Exit:** a provisional implementation passes comprehensive generic synthetic
contract tests; real data always requires human confirmation;
stable-subspace/no-stable-axis is a valid abstention. Scientific validation and
biological operability remain separate later rungs: #67 supplies the
AML-grounded synthetic control and #71 supplies the AML biological exemplar.

### 5. AML-shaped synthetic control — #67 calibration lane

**Deliverable:** repeated synthetic mice, stronger time/nuisance axis, planted
non-dominant condition-by-time target axis, subject-aware atlas/proposal,
component alignment, and typed cross-sectional Stage 2 ineligibility.

**Calibration only:** develop and diagnose on disclosed seeds. Do not consume
the independent acceptance seeds.

### 6. Freeze K=1 acceptance — #51 phase A

**Deliverable:** predeclare generic recovery/thinness/negative controls, #67
metrics, false-positive limits, pass-rate rules, supported-range rule, and
hidden disjoint acceptance seeds in a content-addressed protocol.

**Exit:** protocol identity is immutable before any acceptance aggregation.

### 7. Independent AML-shaped acceptance — #67 acceptance lane

Run the frozen #67 cases without tuning. Preserve all metrics and valid
ineligible/abstention outcomes. Close #67 only when the frozen result is
serialized and reviewable.

### 8. Complete K=1 acceptance — #51 phase B

Run/aggregate the frozen generic controls, incorporate the frozen #67 result,
produce content-addressed artifacts, and amend ADR 0002 with the already-frozen
thresholds, pass rates, false-positive limit, and supported sample range.

### 9. Exploratory primary AML Stage 1 — #71

Fit `primary_2018` only, show the observation-before-interpretation sequence,
require human component confirmation, freeze the state-space definition, and
record either an exploratory result or a structured abstention. This is the
milestone boundary—not a longitudinal Stage 2 result or confirmatory biological
claim.

## Named parallel lanes

- #53 and #54 may run while #61 is implemented.
- The #55 statistical ADR may be drafted during those tasks, but association
  code waits for its acceptance and the v2 lifecycle seam.
- #60 may locate/verify cKit, blast, or flow metadata at any time; it is useful
  atlas enrichment but does not block the primary target/time analysis.
- #57 starts only if #51 or #67 exposes the next real reusable repetition seam;
  it does not justify rewriting stable numerical code in advance.

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

- #57 — backend-independent repetition/compute tiers, triggered by a real
  reusable repetition seam.
- #41 — development-only SSH adapter, triggered only by a frozen run that
  cannot be completed on the available local executor.
- #58 — focused tidy accessors/interoperability after scientific result
  contracts stabilize.
- #56 — Shiny orchestration only after package-owned atlas/proposal/specification
  APIs and claim gates stabilize.
- #5 — consolidate or unexport deferred Stage 0.5/0.75 stubs when the public API
  cleanup lane is opened or the first real implementation begins.

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
| [#51](https://github.com/drejom/landscapeR/issues/51) | Exploratory AML Stage 1 gate | active |
| [#52](https://github.com/drejom/landscapeR/issues/52) | Pogona/bifurcation | queued |
| [#53](https://github.com/drejom/landscapeR/issues/53) | Exploratory AML Stage 1 foundation | complete |
| [#54](https://github.com/drejom/landscapeR/issues/54) | Exploratory AML Stage 1 foundation | complete on merge |
| [#55](https://github.com/drejom/landscapeR/issues/55) | Exploratory AML Stage 1 interpretation | active — next |
| [#56](https://github.com/drejom/landscapeR/issues/56) | Productisation/Shiny | parked |
| [#57](https://github.com/drejom/landscapeR/issues/57) | Conditional infrastructure | conditional |
| [#58](https://github.com/drejom/landscapeR/issues/58) | Productisation/tidy interface | parked |
| [#59](https://github.com/drejom/landscapeR/issues/59) | General multi-axis Stage 2 | queued |
| [#60](https://github.com/drejom/landscapeR/issues/60) | Optional AML metadata enrichment | active, non-blocking |
| [#61](https://github.com/drejom/landscapeR/issues/61) | Exploratory AML Stage 1 foundation | complete |
| [#62](https://github.com/drejom/landscapeR/issues/62) | Longitudinal AML Stage 2 | queued |
| [#63](https://github.com/drejom/landscapeR/issues/63) | Longitudinal extensions | parked |
| [#64](https://github.com/drejom/landscapeR/issues/64) | Longitudinal extensions | parked |
| [#65](https://github.com/drejom/landscapeR/issues/65) | Longitudinal extensions | parked |
| [#66](https://github.com/drejom/landscapeR/issues/66) | Longitudinal observation design | queued |
| [#67](https://github.com/drejom/landscapeR/issues/67) | Exploratory AML Stage 1 acceptance | active |
| [#70](https://github.com/drejom/landscapeR/issues/70) | Roadmap/documentation bootstrap | complete |
| [#71](https://github.com/drejom/landscapeR/issues/71) | Exploratory AML Stage 1 execution | active — milestone exit |
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
| 2026-07-15 | Descriptive component gallery | #54 complete on merge; canonical metadata colour without private ranking |

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
