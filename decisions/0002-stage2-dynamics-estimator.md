# 0002 — Stage 2 dynamics estimator

**Stage:** 2 (quasi-potential / flow)
**Status:** provisional-accepted
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

The following are **provisional targets**, not accepted thresholds. Final
acceptance criteria must be predeclared before the full Stage 0 ladder and
estimated from its independent replicate distribution.

1. **Known-potential recovery** — estimator-level double-well controls must
   measure well-location and barrier-height recovery over a predeclared
   multi-seed replicate set and sample-size grid. The initial targets (well
   location error ≤ 0.15 coordinate units; correctly scaled barrier-height
   recovery) require confirmation or revision from that ladder.
2. **End-to-end recovery** — synthetic multi-omic controls must run through
   Stage 1 and Stage 2, including a stronger shared confounder that makes the
   planted target biological axis non-dominant.
3. **No-hallucination** — predeclared unimodal, no-target-axis, and discordant
   multi-omic negative controls must meet a predeclared false-positive limit.
4. **Cross-sectional native** — the current estimator supports distributional
   quasi-potential claims only; directional or timing claims require a separate
   longitudinal strategy.
5. **Interpretable outputs** — critical point locations and barrier heights are
   reported in the selected target-biological-axis coordinate system.
6. **Pure R** — no MATLAB or reticulate bridge is required.

*Stage 2 cannot move to fully accepted until final numeric thresholds, replicate
pass rates, and negative-control limits are filled from the Stage 0 ladder.*

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

### Exploratory single-seed double-well observation (2026-06-27)

This is an illustrative estimator-level observation, not an acceptance
benchmark: it uses one seed, bypasses Stage 1, and predates the predeclared
replicate and negative-control policy.

`synthetic_potential_control()` + `potential_recovery_benchmark()` on
U(x) = (x²−1)², β=2, seed=42:

| n   | Well pos. error | Barrier x error | Barrier height (recovered) | Wells found | Barriers found |
|-----|-----------------|-----------------|----------------------------|-------------|----------------|
| 100 | 0.104           | 0.225           | 1.391 (true: 1.0, β·U=2.0) | 2           | 1              |
| 200 | 0.066           | 0.263           | 1.065                      | 2           | 1              |
| 500 | 0.036           | 0.124           | 2.052                      | 2           | 1              |

**Preliminary observation only**: Well positions appear to improve with sample
size, and the KDE-space barrier height is consistent with β·U_true = 2·1 = 2.0
(the KDE log-density is β times the physical potential, consistent with the
Boltzmann relation p ∝ exp(−β·U)). These values do not establish reliability or
an acceptance threshold until replicated across the predeclared Stage 0 ladder.

**Implication for real data**: if the full ladder accepts the estimator, report
well positions and barrier heights as dimensionless quasi-potential units. The
β-scaling is absorbed; relative barrier heights between conditions may then be
compared only within the validated claim scope.

## Decision

**Provisional: implement log-density inversion with constrained polynomial
smoothing as `"kde_logdensity"` under the `DynamicsEstimator` contract.**

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
- The predeclared Stage 0 replicate ladder fails its finalized recovery or
  false-positive criteria.
- The end-to-end control fails to recover a planted non-dominant target
  biological axis and its quasi-potential.
- Real data requires spatially-varying diffusion, longitudinal dynamics, or a
  branching/multi-axis geometry (then consider a separately validated strategy).
