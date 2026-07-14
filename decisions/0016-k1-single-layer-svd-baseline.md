# 0016 — K=1 single-layer SVD baseline: synthetic validation before real data

**Status:** accepted  
**Date:** 2026-07-13  
**Depends on:** ADR 0002 (cross-sectional Stage 2 estimator), ADR 0006 (sampling-design capability), ADR 0007 (applicability gate)

---

## ⚠️ STOP RULE — READ BEFORE ANY REAL-DATA ANALYSIS

**No curated/evidentiary real-data single-layer analysis or biological claim
(AML mRNA, Pogona mRNA, CML mRNA) may proceed until the applicable K=1 Stage 0
synthetic ladder in this ADR is complete and its acceptance thresholds and pass
rates are recorded in ADR 0002.** Low-level scientific functions remain
callable under the claim-boundary policy in ADR 0008, but inspect-tier/ad hoc
output is non-evidentiary and does not advance the project past this stop rule.

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
| Generic K=1 cross-sectional double-well | SVD recovers planted state-space axis; current cross-sectional Stage 2 recovers well positions and barrier height | Everything below |
| AML-grounded K=1 longitudinal confounder-separation | Repeated synthetic mice; stronger planted time effect at PC1; planted condition-by-time disease divergence at PC2; sampling-design-aware atlas, proposal, and biological-unit bootstrap recover the target. Current cross-sectional Stage 2 must reject this input as ineligible. | AML Stage 1 recapitulation |
| K=1 thinness sweep | Minimum n for reliable axis recovery at omics-scale p | AML real data |
| K=1 negative control | No false wells when data is pure noise or single-well | AML real data |
| K=1 bifurcation control | Y-shape topology recovered; two wells plus shared early state | Pogona real data |

Each control must produce a frozen artifact (versioned, content-addressed)
before real data may be attempted.

### 3. The confounder-separation control is load-bearing for AML

The AML paper explicitly shows PC1=age, PC2=disease. Any Stage 1 strategy
that returns PC1 as the target biological axis on the AML data is wrong. The
AML-grounded longitudinal K=1 confounder-separation control uses repeated
synthetic mice, a stronger planted time effect, and planted condition-by-time
disease divergence. It must demonstrate that the sampling-design-aware atlas,
component-selection proposal, biological-unit bootstrap, and component
alignment recover the disease axis before curated AML Stage 1 recapitulation begins. It does not
validate the current cross-sectional Stage 2 estimator for longitudinal data;
typed ineligibility at that boundary is the required result under ADR 0006.

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
(a) Extend synthetic_control() to support K=1 and register svd
(b) Run a labelled calibration/development pass on disclosed seeds
(c) Predeclare and freeze the complete K=1 acceptance protocol:
    positive/negative controls, n/p grid, thresholds, false-positive limit,
    hidden acceptance seeds, and pass-rate rules
(d) Run generic cross-sectional recovery + thinness + negative controls on
    the independent frozen acceptance set
(e) Run AML-grounded longitudinal K=1 confounder-separation acceptance control
(f) Freeze acceptance artifacts; record the already-frozen thresholds,
    observed pass rates, and negative-control limit in ADR 0002
── AML Stage 1 recapitulation may begin here (exploratory); longitudinal Stage 2 remains blocked by ADR 0006 ──
(g) Implement K=1 bifurcation control under its separately frozen protocol
(h) Draft bifurcation Stage 2 ADR
── Pogona real data may begin here (exploratory) ──
```

Calibration output chooses the protocol and is permanently non-evidentiary. The
independent acceptance set evaluates the frozen protocol; the same replicates
must not both choose and validate thresholds.

No step may be skipped. Real-data results produced before step (f) are
exploratory and must carry that status in provenance. Confirmatory status
requires a discovery/confirmation boundary (ADR 0008) in addition to (f).

### 6. Domain update status

The K=1 SVD case, AML PC2 target, generic/AML-grounded controls, bifurcation
topology, and confounder-axis language are now recorded in the domain model.
ADR 0002's K=1-specific numeric thresholds, pass rates, and negative-control
limit remain unresolved until the frozen ladder above is complete.

### 7. Exact stationary sampling for the generic double-well control

**Amendment (2026-07-14).** Implementation review found that this ADR specified
independent cross-sectional double-well observations but did not choose how to
sample them. That omission allowed a finite-chain sampler to be implemented
without an explicit algorithm decision. This amendment records the correction
before the frozen #51 acceptance protocol or any acceptance replicate exists.
No acceptance result was inspected in making this choice.

Options considered:

| Option | Property | Disqualifier or concern |
|---|---|---|
| Thin one Langevin or Metropolis trajectory | Familiar dynamical simulation | Observations remain serially dependent and finite burn-in does not provide exact stationary ground truth |
| Run one finite Markov chain per observation | Removes cross-observation dependence | Finite-chain convergence still makes the declared stationary density approximate and tuning-dependent |
| Numerically invert a discretized stationary CDF | Independent draws | Grid truncation and resolution become unrecorded approximation parameters |
| Rejection sample with a standard-Cauchy proposal | Independent exact stationary draws with an analytic envelope and no new dependency | Less directly connected to the deferred longitudinal dynamics simulator |

Criteria, fixed before #51 evidence:

- draws are independent and exactly target
  \(p(x) \propto \exp[-\beta(x^2-1)^2]\);
- no burn-in, thinning, convergence diagnostic, grid, or hidden tuning parameter
  can alter the answer key;
- the sampler is deterministic under the declared seed and needs no new package
  dependency;
- the generated quasi-potential remains in the Stage 2 units
  \(-\log p(x)=\beta(x^2-1)^2+C\);
- output remains labelled disclosed, non-evidentiary calibration.

**Chosen:** standard-Cauchy rejection sampling. For proposal density
\(q(x)=1/[\pi(1+x^2)]\), the unnormalised target-to-proposal ratio is

\[
\pi(1+y)\exp[-\beta(y-1)^2], \qquad y=x^2.
\]

Its maximum occurs at
\(y_*=\sqrt{1+1/(2\beta)}\), which gives an analytic finite envelope constant.
Accepting proposals against that envelope therefore produces independent exact
stationary draws without estimating the target normalising constant.

Consequences:

- `n_steps`, burn-in, thinning, and integration-step parameters do not belong to
  the generic cross-sectional K=1 control;
- Langevin/Fokker--Planck trajectory simulation remains a separate deferred
  longitudinal capability and must not be inferred from this sampler;
- changing the target density or proposal/envelope requires a new ADR amendment
  before calibration or acceptance output is generated;
- #51 may use this generator only after freezing its own disjoint calibration
  and acceptance seeds and metrics.

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

- **AML Stage 1 real data (`data-raw/aml_mrna_std.rds`)**: blocked until steps
  (a)–(f) are complete
- **AML Stage 2 real data**: additionally blocked until a separately registered
  longitudinal `DynamicsEstimator` has its own ADR and Stage 0 ladder, or a
  distinct scientifically justified cross-sectional estimand is predeclared;
  repeated observations may not be pooled as independent
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
- Claude session `86b77184`: AML PC1=age, PC2=disease first identified
