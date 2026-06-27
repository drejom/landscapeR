# 0002 — Stage 2 dynamics estimator

**Stage:** 2 (quasi-potential / flow)
**Status:** proposed
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

**Not yet available.** Stage 0 known-potential controls have not been run.

The log-density inversion approach is the most transparent and easiest to
audit against Stage 0 ground truth. TRAMWAY has published benchmarks on
synthetic Langevin data but in Python. Schrödinger bridge methods are
state-of-the-art but the R ecosystem for them is thin.

## Decision

**Unresolved.** This is the most consequential open question in the pipeline.
Do not implement Stage 2 until:
1. Stage 0 known-potential controls are designed and the recovery criteria above
   are filled in with specific numbers.
2. At least the log-density inversion baseline is benchmarked against those controls.

## Consequences

- Stage 2 implementation is explicitly blocked on Stage 0 results.
- The `DynamicsEstimator` contract and `PotentialGroundTruth` class are defined
  (already scaffolded) so Stage 0 can test the interface before the estimator exists.

## Review trigger

Revisit when Stage 0 double-well recovery results are available. Fill in the
[tbd] thresholds in criteria 1–2 before running any comparison.
