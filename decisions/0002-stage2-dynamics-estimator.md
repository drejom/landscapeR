# 0002 — Stage 2 dynamics estimator

**Stage:** 2 (quasi-potential / flow)
**Status:** proposed → provisional (pending Stage 0 thresholds)
**Date:** 2026-06-27

## Context

Stage 2 fits dX/dt = −∇U(X; layer) + noise and reads out critical points and
barrier heights from cross-sectional snapshots. This is an ill-posed inverse
problem with no ground truth in real data — Stage 0 (known-potential controls)
is the only honest test.

The choice of estimator has large downstream consequences: it determines what
"barrier height" means, what the computational cost is, and whether the
Fokker-Planck / density-based framing holds. Cross-sectional (destructive)
sampling is the native data type, so the estimator must not require longitudinal
tracks.

## Options considered

| Option | Key property | Rank in design space |
|---|---|---|
| Log-density inversion (kernel density → −log p(x)) | Simplest; directly implements the Boltzmann relation U ∝ −log p; no dynamics model assumed | Starting point |
| TRAMWAY / local diffusion maps | Estimates local drift + diffusion from position density; handles spatially varying noise | More faithful to Langevin; computationally heavier |
| Schrödinger bridge / OT flow matching | Recovers the stochastic interpolant between marginals; cross-sectional native | Theoretically strong; Python-heavy ecosystem (torchdyn, ott-jax) |
| Potential landscape via RKHS gradient | Fits −∇U directly as an RKHS function; smooth, differentiable | Requires good kernel bandwidth choice; less interpretable barriers |

## Criteria

1. **Known-potential recovery** — the double-well Stage 0 control must recover well
   positions within [tbd]% and barrier height within [tbd]% across the planned
   sweep (barrier height × sampling density).
2. **No-hallucination** — the static-Gaussian negative control must yield zero
   detected critical points at the planned false-positive threshold.
3. **Cross-sectional native** — no longitudinal tracks required by assumption.
4. **Interpretable outputs** — must emit critical point locations and barrier heights
   in units that map back to the Stage 1 coordinate system.
5. **R implementable** — pure R or a bounded reticulate bridge.

## Evidence

### From reference implementation (ADR 0003)

The Rockne-Frankhouser group uses log-density inversion across three published
papers (AML Cancer Research 2020, CML Leukemia 2024, CML miRNA Science Advances).
Their implementation (cohmathonc/CML_mRNA_state-transition) is:

1. KDE over SVD coordinates → p(x)
2. U(x) = −log p(x) at identified critical points (Boltzmann relation)
3. Constrained polynomial fit (6th degree): simultaneously match U at critical
   points AND zero gradient at critical points → smooth quasi-potential
4. Barrier height = U(saddle) − U(well) from the polynomial

This approach works in 1D (first SVD component). Published results in two disease
contexts support its biological validity.

The Schrödinger bridge / OT flow matching and TRAMWAY options are more
theoretically general but: (a) no R implementations of comparable maturity,
(b) no published validation in this biological context, (c) harder to audit
against Stage 0 ground truth given their complexity.

### From Stage 0: not yet available

Stage 0 double-well recovery benchmarks have not been run. The criteria
thresholds marked [tbd] below must be filled in before accepting this decision.

## Decision

**Provisional: implement log-density inversion with constrained polynomial
smoothing as `"log_density_poly"` under the `DynamicsEstimator` contract.**

Rationale: (a) validated in the reference implementation across multiple disease
contexts, (b) directly interpretable against Stage 0 ground truth, (c) R
implementable without reticulate. Polynomial degree and KDE bandwidth are
parameters so Stage 0 can sweep them.

The decision becomes **accepted** when Stage 0 double-well controls confirm
recovery within the criteria below. If recovery fails, revisit TRAMWAY or
RKHS gradient approaches — but test the simple thing first.

**Criteria thresholds (fill in before marking accepted):**
- Well position recovery within [tbd] % of planted positions
- Barrier height recovery within [tbd] % of planted height
- False-positive rate (static Gaussian → no critical points) ≤ [tbd]
- Recovery holds at n ≥ [tbd] samples per state

## Consequences

- `LangevinDynamicsEstimator` / `LogDensityPolyEstimator` is the first concrete
  implementation to write for Stage 2.
- KDE bandwidth selection must be a parameter (not hard-coded); Silverman's
  rule as default, cross-validated as alternative.
- Polynomial degree must be a parameter; 6 as default matching reference impl.
- Fokker-Planck forward propagation (`SolveFP` equivalent) is a separate
  capability — not required for critical-point detection, needed later for
  trajectory prediction and the Golem reward field.

## Review trigger

Revisit when Stage 0 double-well recovery results are available. Fill in the
[tbd] thresholds in criteria 1–2 before running any comparison.
