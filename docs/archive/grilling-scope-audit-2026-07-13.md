# K=1 / component-selection grilling scope audit — 2026-07-13

> **Historical audit.** This document preserves the reconciliation that produced
> the K=1 issue set. It is superseded for scheduling by the root
> [`ROADMAP.md`](../../ROADMAP.md); its “next” and sequence language must not be
> used to select current work.

**Status:** complete  
**Audit type:** decision, issue, and implementation-scope reconciliation  
**No scientific algorithm was selected or implemented during this audit.**

## Purpose

Consolidate the K=1, component-selection, sampling-design, execution, and deferred-interface decisions made during the 2026-07-13 grilling session. Identify contradictions, duplicates, scope creep, and the shortest defensible implementation sequence.

## Executive conclusion

The grilling produced a coherent K=1 scientific direction, but it drifted into several valuable future capabilities that are not prerequisites for the immediate objective. The immediate objective remains:

> Validate a first-class single-layer `svd` strategy and its component-selection workflow on frozen K=1 synthetic controls before curated AML Stage 1 analysis.

Longitudinal AML Stage 2, 2D/bifurcation dynamics, Shiny, the full tidy interface, scheduler infrastructure, alternative longitudinal estimands, and heterogeneous diffusion are now explicitly parked. They shape interfaces but do not block the K=1 foundation unless named below.

## Decisions now settled

1. **K=1 is first-class.** It uses a registered `svd` strategy, not a K=1 branch inside `hogsvd_averaged` (ADR 0016).
2. **Observation precedes interpretation.** Structured descriptive evidence remains visible beside hypothesis-conditioned output (ADR 0017).
3. **Component interpretation is human-in-the-loop for real data.** The flow is metadata atlas → proposal → confirmation; synthetic truth permits automated proposal assertions.
4. **A confirmed specification retains both target intent and `selected_component`.** `manual_component` and the target/component XOR are superseded (ADR 0008 amendment; issue #61).
5. **Target direction uses neutral language.** Binary targets declare `reference_level` and `comparison_level`; ordered targets declare their full order.
6. **Sampling design controls association and claim semantics.** Repeated mice cannot be treated as independent (ADR 0006).
7. **Projection is optional and downstream.** The discovery state space is immutable; secondary cohorts never refit or rerank it.
8. **AML cohort roles are fixed.** `primary_2018` defines the state space. `supp_2016` is a batch/time-confounded robustness stress test, not clean independent confirmation.
9. **Cross-sectional and longitudinal Stage 2 are separate capabilities.** Current `kde_logdensity` is cross-sectional-only. AML longitudinal Stage 2 remains deferred.
10. **Execution and ergonomics are staged.** `future.apply` plus targets/crew and a tidyomics-inspired interface are accepted directions, not immediate rewrite projects (ADRs 0018–0019).
11. **Guard claims, not function calls.** Experts may compose low-level functions; evidence tooling prevents ad hoc work from being silently labelled confirmatory.

## Contradictions corrected during this audit

### K=1 threshold leakage

ADR 0016 previously set thresholds immediately from the first double-well output, before thinness and negative controls. It now separates:

1. disclosed calibration/development output;
2. a predeclared frozen protocol and hidden acceptance seeds;
3. independent acceptance execution;
4. final recording of already-frozen thresholds, pass rates, and false-positive limits in ADR 0002.

The same replicates cannot choose and validate thresholds.

### Incorrect K=1 dependency on multi-layer v3

ADR 0015 governs the unresolved K≥2 protocol v3 and is no longer a normative dependency of the K=1 SVD ladder.

### Projection coordinate mismatch

The canonical ordinary-SVD score convention is:

```text
(X_new − discovery_center) · V_training = U_new Σ_training
```

Do not independently centre the secondary cohort and do not divide scores by singular values. ADR 0009 feature identity and discovery-preprocessing requirements remain mandatory. Current `project_into()` still violates the discovery-centering requirement; issue #24 owns the implementation repair.

### Stale component-selection defaults

ADR 0005 is amended: the atlas/proposal owns scientific scores and ranking; plots render structured results. The curated Stage 2 path requires a confirmed `selected_component` and never silently defaults to component 1. Low-level explicit component calls remain exploratory/composable.

### Overstated Stage 1 language

Unsupervised SVD/GSVD produces candidate axes; it does not explicitly construct a condition contrast. Biological meaning is assigned through the metadata atlas, proposal, and confirmation workflow. No K≥2 production strategy is currently accepted after the v2 negative result.

### Over-broad Stage 2 dependency claim

`deSolve` and `ReacTran` belong to the deferred longitudinal/Fokker–Planck decision, not the current cross-sectional estimator's critical-path Imports.

### Stale GitHub issues

Issue bodies #49, #50, #51, #54, #55, #62, and #66 were narrowed/reconciled. Issue #67 now separately owns the AML-grounded K=1 longitudinal confounder-separation control.

## Remaining load-bearing gaps

### 1. K=1 computational foundation — #50

- permit K=1 generation;
- register `svd` under `Decomposer`;
- common `DecompositionResult` output and truthful provenance;
- deterministic subspace tests;
- generic cross-sectional calibration harness.

This is the next implementation target.

### 2. Metadata association strategy decision — #55

Before association code, write an ADR defining swappable association strategies and criteria for:

- cross-sectional binary/continuous/ordered targets;
- longitudinal condition × time assessment;
- adjusted versus unadjusted effect sizes;
- biological-unit uncertainty and multiplicity;
- abstention and minimum-data behaviour.

The atlas/proposal object shape is settled; the concrete statistical strategies are not.

### 3. AnalysisSpecification v2 — #61

Implement versioned migration from `manual_component`/XOR semantics to retained target declaration plus `selected_component`, proposal digest, accept/override status, and rationale. Do not fabricate missing target intent for legacy objects.

### 4. AML source metadata — #53 and #60

- preserve the authoritative decimal weeks column exactly;
- do not derive time from `T0`/`L` labels;
- locate cKit/blast/flow metadata and verify definitions/mapping;
- preserve source endpoint tokens without claiming disease onset until verified.

Only decimal weeks is load-bearing for AML longitudinal interpretation; cKit/blast restoration is valuable supporting metadata but not required to define `condition` as the primary target.

### 5. Plot repair — #54

Fix MAE-level metadata/sample alignment and visual rendering. Do not make the plot the statistical scoring engine.

### 6. AML-grounded Stage 1 acceptance control — #67

After #50 and the atlas/proposal foundation:

- repeated synthetic mice;
- stronger time axis;
- non-dominant condition × time disease axis;
- subject-aware association;
- component/subspace alignment and stability;
- typed Stage 2 longitudinal ineligibility.

### 7. Frozen K=1 acceptance — #51

Run independent generic recovery, thinness, negatives, and #67 under one frozen protocol. Then record thresholds/pass rates in ADR 0002.

### 8. Projection safety — invariant parts of #24

Sample mapping, canonical feature IDs, discovery preprocessing, typed failures, and permutation tests can proceed independently of K≥2 candidate selection. They are required before projecting `supp_2016` after the primary AML Stage 1 analysis.

### 9. K≥2 protocol v3 inconsistency — #49

ADR 0015 remains provisional and internally contains both `q90 + margin` and revised `median − 0.05` formulations, calls a noisy empirical reference an oracle, and mentions SRE under pure noise where no planted subspace exists. Reconcile these before any v3 run. This lane is independent of K=1 and must not delay #50.

## Shortest defensible work sequence

### Parallel foundation after this audit

1. **#50** — K=1 generator + registered `svd` + generic calibration harness.
2. **#54** — narrow component-gallery metadata alignment repair.
3. **#61** — `AnalysisSpecification` v2 and migration.
4. **#53** — preserve authoritative numeric weeks.
5. **#24 invariant subset** — sample/feature/projection safety independent of a K≥2 candidate.
6. **Association-strategy ADR for #55** — decision work, no implementation until criteria are frozen.

### Then

7. Implement #55 atlas/proposal phases using the accepted association ADR.
8. Implement #67 AML-grounded Stage 1 control.
9. Freeze and run #51 independent K=1 acceptance protocol.
10. Amend ADR 0002 with frozen K=1 thresholds, pass rates, false-positive limit, and supported n range.
11. Run exploratory AML `primary_2018` Stage 1 recapitulation.
12. After #24 passes, project `supp_2016` as robustness/stress-test evidence only.

## Explicitly parked

| Work | Issues | Why parked |
|---|---|---|
| K≥2 candidate/protocol v3 | #49 | Separate lane; ADR 0015 must first be reconciled |
| Longitudinal AML Stage 2 | #62 | Research/ADR only after immediate K=1 Stage 1 path; no implementation yet |
| Alternative longitudinal models/diffusion | #63–#65 | Depend on accepted #62 baseline |
| Event/censoring contract | #66 | Deferred observation-design extension; not the barrier-crossing target |
| Pogona bifurcation / general 2D | #52, #59 | Requires separate topology/dimensionality ADRs and controls |
| Shiny | #56 | Future interaction layer; scientific API must stabilise first |
| Full tidy interface | #58 | Accepted direction, explicitly non-blocking |
| Execution substrate migration | #57 | Implement incrementally when the next repeated-compute seam needs it |
| Developer SSH adapter | #41 | Park unless immediately required for a frozen remote evidence run |
| Projection-only incomplete blocks | #22 | Separate missingness evidence after complete-cohort projection is safe |

## Scope-creep assessment

### Productive interface shaping

ADRs 0017–0019, proposal objects, claim-boundary guardrails, and future Shiny/tidy direction are useful because they prevent scientific results from being trapped in plotting code or tied to one machine. Their implementation is deferred.

### Genuine drift that is now stopped

The discussion moved too far into longitudinal Stage 2 model variants, endpoint/survival semantics, and heterogeneous diffusion before completing K=1 SVD. Those ideas are now parked in #62–#66. No further longitudinal estimator design should occur in the immediate K=1 implementation thread.

### Immediate focus

Do not start AML real-data work, longitudinal dynamics, Shiny, full tidy refactoring, or K≥2 candidate implementation in the next task. Start #50 test-first, while the small independent contract/data tasks above can proceed separately.

## Audit evidence

Reviewed:

- ADRs 0002, 0005–0009, 0015–0019;
- `context/shared.md`, `context/stage0.md`, `context/stage1.md`, `context/stage2.md`;
- current `AnalysisSpecification`, `SamplingDesign`, generator, decomposition, plotting, projection, Stage 2, and execution code;
- open issues #24, #41, and #49–#67.

No code or numeric scientific result changed in this audit.
