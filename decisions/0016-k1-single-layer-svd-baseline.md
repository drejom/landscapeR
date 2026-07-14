# 0016 — K=1 single-layer SVD baseline: synthetic validation before real data

**Status:** accepted  
**Date:** 2026-07-13  
**Depends on:** ADR 0002 (Stage 2 estimator), ADR 0007 (applicability gate), ADR 0015 (v3 thresholds)

---

## ⚠️ STOP RULE — READ BEFORE ANY REAL-DATA ANALYSIS

**No real-data single-layer analysis (AML mRNA, Pogona mRNA, CML mRNA) may
proceed until the K=1 Stage 0 synthetic ladder in this ADR is complete and
its acceptance thresholds are recorded in ADR 0002.**

This rule exists because it was violated once already: multi-layer (K≥2)
complexity was pursued before the simplest case (K=1, plain SVD) had a
validated synthetic baseline. Do not repeat this.

---

## Context

The Frankhouser/Rockne 2020 Cancer Research paper (AML, GSE133642) uses a
**single mRNA matrix** (K=1) decomposed by plain SVD. **PC2 is the disease
axis — PC1 encodes age** and is treated as a nuisance variable in that paper.
The 2018 primary cohort (101 mice) is used for SVD; the 2016 supplementary
cohort (132 mice) is projected into that state-space.

This is the reference result landscapeR must recapitulate before any biological
claim is made. The data is prepared (`data-raw/aml_mrna_std.rds`). The pipeline
plumbing exists. But the K=1 case:

- is not validated by any Stage 0 synthetic control
- is not covered by any ADR 0002 acceptance threshold
- is hard-gated out of the current `synthetic_control()` generator (`K >= 2`)
- has no registered `Decomposer` strategy that accepts K=1 input cleanly

The Pogona TSD data (single mRNA layer, K=1) has a **bifurcation topology**:
undifferentiated early embryos occupy a shared state that later diverges into
distinct male and female attractors — a Y-shape in PC1/PC2 biplot space. This
is a different quasi-potential topology from the AML double-well and requires
its own Stage 0 control and ADR before Pogona real data is attempted.

---

## Decision

### 1. K=1 is a first-class capability requiring its own Stage 0 ladder

K=1 (plain SVD on a single omic layer) is not a degenerate special case to be
handled by a guard clause. It is the reference algorithm for all published
results this package must recapitulate. It requires:

- its own Stage 0 synthetic controls with known ground truth
- its own acceptance thresholds in ADR 0002
- its own registered `svd` `Decomposer` strategy

### 1a. Plain SVD is a separate registered strategy

K=1 uses a first-class `svd` strategy selected explicitly through
`PipelineConfig`. It accepts exactly one omic layer and returns the same
`DecompositionResult` contract as multi-layer strategies. `hogsvd_averaged`
remains K≥2 and does not contain a hidden K=1 degradation branch. This keeps
provenance, parameters, eligibility, and Stage 0 evidence truthful; orchestration
must not auto-switch strategies from layer count.

### 2. The K=1 Stage 0 ladder must be completed before any real-data K=1 analysis

**Mandatory Stage 0 controls for K=1, in order:**

| Control | What it validates | Blocks |
|---|---|---|
| K=1 double-well synthetic | SVD recovers planted state-space axis; Stage 2 recovers well positions and barrier height | Everything below |
| K=1 confounder-separation | Target axis is PC2 (not PC1); nuisance variable dominates PC1; component-selection proposal ranks correctly | AML real data |
| K=1 thinness sweep | Minimum n for reliable axis recovery at omics-scale p | AML real data |
| K=1 negative control | No false wells when data is pure noise or single-well | AML real data |
| K=1 bifurcation control | Y-shape topology recovered; two wells plus shared early state | Pogona real data |

Each control must produce a frozen artifact (versioned, content-addressed)
before real data may be attempted.

### 3. The confounder-separation control is load-bearing for AML

The AML paper explicitly shows PC1=age, PC2=disease. Any Stage 1 strategy
that returns PC1 as the target biological axis on the AML data is wrong. The
K=1 confounder-separation control (planted confounder stronger than planted
disease axis) must demonstrate that the component-selection proposal correctly
ranks the disease axis above the confounder axis before AML data is loaded.

### 4. The bifurcation topology is explicitly out of scope until its own ADR exists

The Pogona Y-shape (one early attractor splitting into two) is geometrically
and topologically different from the AML double-well. ADR 0007 already records
this: *"a future 2D or bifurcation Stage 2 strategy requires a separate ADR
and Stage 0 bifurcation-control ladder before use on Pogona or other real data."*

The K=1 bifurcation Stage 0 control in this ADR validates *detection* of a
branching topology — it does not imply a Stage 2 estimator exists for it.
Pogona real data analysis requires both this control AND a new ADR for the
bifurcation estimator.

### 5. The development sequence is fixed

```
(a) Extend synthetic_control() to support K=1
(b) Implement K=1 Stage 0 double-well control → freeze artifact
(c) Set ADR 0002 K=1 acceptance thresholds from (b)
(d) Implement K=1 confounder-separation control → freeze artifact
(e) Implement K=1 thinness sweep → freeze artifact
(f) Implement K=1 negative control → freeze artifact
── AML real data may begin here (exploratory) ──
(g) Implement K=1 bifurcation control → freeze artifact
(h) Draft bifurcation Stage 2 ADR
── Pogona real data may begin here (exploratory) ──
```

No step may be skipped. Real-data results produced before step (f) are
exploratory and must carry that status in provenance. Confirmatory status
requires a discovery/confirmation boundary (ADR 0008) in addition to (f).

### 6. Domain gaps to fix before implementation

The following are missing from the domain model and must be corrected before
code is written:

- **`context/stage1.md`**: K=1 SVD as a valid degenerate case of comparative
  decomposition; the fact that PC2 (not PC1) is the target in the AML reference
- **`context/stage0.md`**: K=1 double-well and confounder-separation controls
  as named domain concepts; bifurcation control as a named concept
- **`UBIQUITOUS_LANGUAGE.md`**: bifurcation topology; Y-shape as a recognisable
  archetype; confounder axis vs target biological axis in the K=1 context
- **ADR 0002**: K=1-specific acceptance thresholds (currently all `[tbd]` and
  implicitly written for multi-layer)

---

## What "bifurcation topology" means in this context

The Pogona TSD mRNA data shows a **Y-shape in PC1/PC2 biplot space**: early
embryos (undifferentiated, shared developmental state) cluster together, and
later time points diverge into distinct male and female attractors. This is:

- **not** a double-well (the two wells are not separated by a single barrier
  from a common unstable point — they emerge from a shared region)
- **not** a three-well (no third stable state)
- a **branching quasi-potential**: a region of marginal stability that resolves
  into two separate wells as a function of developmental progression

This topology is currently outside the scope of the Stage 2 KDE estimator.
It requires a 2D or time-aware estimator and a separate ADR.

---

## Consequences

- **AML real data (`data-raw/aml_mrna_std.rds`)**: blocked until steps (a)–(f)
  are complete
- **Pogona real data**: blocked until steps (a)–(h) are complete
- **CML mRNA single-layer**: blocked until steps (a)–(f) are complete (same
  K=1 ladder; different biology but same validation requirement)
- **CML mRNA + miRNA (K=2)**: blocked until K=1 ladder is complete AND K=2
  multi-layer validation (a new Stage 0 ladder, informed by ADR 0015) is
  complete
- **Issue #49** (v3 protocol): runs in parallel — it addresses the K≥2
  multi-layer algorithm; this ADR addresses K=1. They do not block each other
  at the Stage 0 level, but K=2 real data requires both

---

## References

- AML data: `data-raw/README.md`, GSE133642, Cancer Research 2020
- Pogona data: not yet loaded; planned as K=1 mRNA single-layer
- CML mRNA+miRNA: `data-raw/aml_multimodal_std.rds` (loaded), only published
  multimodal dataset currently available
- ADR 0002: `decisions/0002-stage2-dynamics-estimator.md` (K=1 `[tbd]` thresholds)
- ADR 0007: `decisions/0007-stage0.5-0.75-archetype-applicability-gate.md`
- ADR 0015: `decisions/0015-stage1-protocol-v3-threshold-calibration.md`
- Claude session `86b77184`: AML PC1=age, PC2=disease first identified
