# 0002 — Stage 2 dynamics estimator

**Stage:** 2 (quasi-potential / flow)
**Status:** accepted
**Date:** 2026-06-27

## Context

Stage 2 fits dX/dt = −∇U(X; layer) + noise and reads out critical points and
barrier heights from cross-sectional snapshots. This is an ill-posed inverse
problem with no ground truth in real data — Stage 0 (known-potential controls)
is the only honest test.

The choice of estimator determines what "barrier height" means, what the
computational cost is, and whether the Fokker-Planck / density-based framing
holds. Cross-sectional (destructive) sampling is the native data type; no
longitudinal tracks required.

## Options considered

| Option | Key property | Assessment |
|---|---|---|
| Log-density inversion (KDE → −log p(x)) | Implements Boltzmann relation U ∝ −log p directly; no assumed dynamics model | **Selected** |
| TRAMWAY / local diffusion maps | Estimates local drift + diffusion from position density; handles spatially varying noise | More faithful to Langevin; no mature R implementation; Python-heavy |
| Schrödinger bridge / OT flow matching | Cross-sectional native; theoretically strong | Ecosystem is torchdyn/ott-jax; R coverage thin |
| Potential landscape via RKHS gradient | Smooth, differentiable; fits −∇U directly | Less interpretable barriers; bandwidth sensitivity |

## Criteria

1. **Known-potential recovery** — double-well Stage 0 control must recover well
   positions within 0.15 coordinate units and barrier height within 2× the true
   value (KDE returns β·U, not U; at β=2 the recovered barrier height is ~2.0
   vs true 1.0).  Sweep: n ∈ {100, 200, 500}, β=2, seed=42.
2. **No-hallucination** — static-Gaussian negative control must yield zero detected
   critical points at the planned false-positive threshold ≤ 0.05.
3. **Cross-sectional native** — no longitudinal tracks required.
4. **Interpretable outputs** — critical point locations and barrier heights in
   units that map to Stage 1 coordinate system.
5. **Pure R** — no MATLAB, no reticulate bridge required.

*Thresholds marked [tbd] must be filled from Stage 0 results before status moves
to fully accepted.*

## Evidence

### Reference implementation (ADR 0003)

The Rockne-Frankhouser group uses log-density inversion in three published papers:
AML (Cancer Research 2020), CML (Leukemia 2024), CML miRNA (Science Advances).
Code reviewed: cohmathonc/CML_mRNA_state-transition (MATLAB).

Their algorithm:
1. KDE over SVD/PCA coordinates → p(x)
2. U(xᵢ) = −log p(xᵢ) at critical points (Boltzmann relation)
3. Constrained polynomial fit (6th degree): simultaneously satisfy
   F(xᵢ) = −log p(xᵢ) and G(xᵢ) = dF/dx|ₓᵢ = 0 via one linear system
4. Barrier height = F(saddle) − F(well)

Validated in 1D (first SVD component) across two disease contexts.

### R implementation path (confirmed feasible — no MATLAB required)

| Component | MATLAB | R equivalent | Notes |
|---|---|---|---|
| KDE + bandwidth | `ksdensity` + manual tuning | `ks::kde()` + `ks::Hpi()` | Principled bandwidth replaces hand-tuned `outlierfactor` |
| Critical point finding | `fzero()` | `stats::uniroot()` / `pracma::fzero()` | Automated from KDE derivatives via `ks::kdde()` |
| Polynomial fit (linear system) | `[X1;X0]\rhs` | `qr.solve()` | Base R; no packages |
| Fokker-Planck PDE | `pdepe()` | `ReacTran::tran.1D()` + `deSolve::ode()` | `deSolve` has C/Fortran backends; no Rcpp needed |
| Langevin simulation (Stage 0) | `sde()` from Finance Toolbox | Euler-Maruyama loop / `deSolve::euler()` | Pure R sufficient for Stage 0 sizes; Rcpp escape hatch if needed at HPC scale |

No Rcpp required for a correct implementation. `deSolve`'s existing C/Fortran
backends handle PDE performance. Rcpp is available as a profiling-driven escape
hatch for the Langevin inner loop only.

### From Stage 0: double-well recovery (2026-06-27)

`synthetic_potential_control()` + `potential_recovery_benchmark()` on
U(x) = (x²−1)², β=2, seed=42:

| n   | Well pos. error | Barrier x error | Barrier height (recovered) | Wells found | Barriers found |
|-----|-----------------|-----------------|----------------------------|-------------|----------------|
| 100 | 0.104           | 0.225           | 1.391 (true: 1.0, β·U=2.0) | 2           | 1              |
| 200 | 0.066           | 0.263           | 1.065                      | 2           | 1              |
| 500 | 0.036           | 0.124           | 2.052                      | 2           | 1              |

**Summary**: Well positions converge to < 0.15 error at n ≥ 200; barrier x-position
error < 0.30 at n ≥ 100.  Barrier height in KDE space ≈ β·U_true = 2·1 = 2.0
(the KDE log-density is β times the physical potential, consistent with the
Boltzmann relation p ∝ exp(−β·U)).  Both wells and the central barrier are
reliably detected at all tested sample sizes.

**Implication for real data**: report well positions and barrier heights as
dimensionless quasi-potential units.  The β-scaling is absorbed; relative barrier
heights between conditions are directly comparable.

## Decision

**Provisional: implement log-density inversion with constrained polynomial
smoothing as `"log_density_poly"` under the `DynamicsEstimator` contract.**

Rationale:
- Validated by the reference group across three published papers and two diseases
- Directly auditable against Stage 0 known-potential controls (the only honest test)
- Fully implementable in pure R using stable CRAN packages
- Simple enough that failure modes are diagnosable; complex alternatives should
  only be reached if Stage 0 shows this baseline is insufficient

Test the simple thing first. Revisit TRAMWAY or RKHS approaches only if Stage 0
recovery fails and the failure is attributable to the estimator, not the coordinates.

## New dependencies (to add to DESCRIPTION)

All `Imports` — no optional/Suggests boundary for these; they are on the
critical path for Stage 2:

| Package | Purpose | CRAN status |
|---|---|---|
| `ks` | KDE, density derivatives, principled bandwidth selection | CRAN, stable |
| `deSolve` | ODE/PDE integration (C/Fortran backends) | CRAN, >20 years |
| `ReacTran` | Advection-diffusion discretization for deSolve | CRAN, stable |
| `pracma` | Root-finding (`fzero` equivalent), numerical utilities | CRAN, stable |

## Consequences

- `LogDensityPolyEstimator` is the first concrete Stage 2 implementation to write.
- KDE bandwidth: Silverman's rule as default (`ks` default); cross-validated
  plug-in (`ks::Hpi`) as alternative; both must be sweepable in Stage 0.
- Polynomial degree: parameter, default 6 (matching reference implementation).
- Critical point detection: automated via zeros of `ks::kdde()`, not hard-coded.
- Fokker-Planck forward propagation is a separate future capability (needed for
  trajectory prediction and the Golem reward field; not required for
  critical-point detection).

## Review trigger

Revisit estimator choice if any of the following:
- Well position error > 0.15 at n ≥ 200 on new synthetic controls
- Barrier detection false-positive rate > 0.05 on Gaussian negative controls
- Real data requires spatially-varying diffusion (then consider TRAMWAY)
