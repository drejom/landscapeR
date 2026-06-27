# 0003 — Reference implementation: Rockne-Frankhouser state-transition code

**Stage:** cross-cutting
**Status:** accepted
**Date:** 2026-06-27

## Context

The Rockne-Frankhouser group at City of Hope / Mathon Institute has published
state-transition analysis of omic data across multiple disease contexts:

- AML: Cancer Research 2020 (time-sequential gene expression)
- CML: bioRxiv 2023 / Leukemia 2024 (blood transcriptome, treatment response)
- CML microRNA: Science Advances (miRNA transcriptome state-transition)

Code reviewed: **https://github.com/cohmathonc/CML_mRNA_state-transition**
(CML paper — different disease from the diabetes target but same algorithmic approach)

This code is analysis scripts, not a package. It is the reference implementation
of the quasi-potential / critical-point approach on real omic data, and the thing
landscapeR is generalising and formalising.

It is NOT a source of architecture — landscapeR deliberately imposes the
contract/registry/provenance structure the reference code lacks.

## Algorithm extracted from code review

### Coordinate space (Stage 1 stand-in)

SVD on the expression matrix; work in the first principal component only (1D).
Later versions use "rotated space" (commented-out x0 values suggest they explored
2D but published results are 1D). Critical points are identified in this coordinate.

### Stage 2 — quasi-potential estimation

**Method: log-density inversion with constrained polynomial smoothing.**

Step-by-step:
1. Identify critical points x₀ in SVD coordinate space (by KDE peak-finding,
   done externally — hard-coded as vectors in the scripts).
2. Evaluate kernel density p(xᵢ) at those critical points → values `f`.
3. Set U(xᵢ) = −log p(xᵢ) → values `y`. This is the Boltzmann relation
   U ∝ −log p_stationary.
4. Fit a 6th-degree polynomial F(x) simultaneously constrained to:
   - F(xᵢ) = yᵢ (match −log p at critical points)
   - G(xᵢ) = dF/dx|ₓᵢ = 0 (zero gradient at critical points — they are extrema)
   Solved as a single linear system: [G_matrix; F_matrix] * a = [0; y]
5. F(x) is the smooth quasi-potential. Its zeros of the gradient G(x) = dF/dx
   give stable wells (local minima) and unstable saddle points.
6. Barrier height = F(saddle) − F(well).
7. Optional: propagate forward via Fokker-Planck PDE (`pdepe`) to get time
   evolution and treatment trajectories (SolveFP_*.m scripts).

### Hard-coded assumptions / known limitations

| Assumption | Where it appears | landscapeR must generalise |
|---|---|---|
| 1D coordinate space | x0 is a scalar vector; F, G are univariate | Extend to 2D+ Stage 1 subspace |
| Critical points identified by hand | x0 values hard-coded; changed between versions | Automate via KDE peak-finding |
| 6th-degree polynomial | Hard-coded degree in X0, X1 construction | Make degree a parameter |
| Manual bandwidth tuning | `outlierfactor` scalar; many commented-out f values | Principled bandwidth selection (e.g. Silverman, cross-validated) |
| Manual [0,1] normalisation | Linear rescaling of x0 to [0,1] before fitting | Principled or documented normalisation |
| Constant diffusion coefficient D | `Diff = @(t,X) sqrt(2*D)` with D fixed | Spatially varying D is more realistic but harder |
| MATLAB / no package structure | Scripts, no functions, no tests | Not a limitation to carry forward |

### What this confirms for ADR 0002

The algorithm is definitively **log-density inversion**: U(x) = −log p(x),
with polynomial smoothing as the only step that goes beyond the raw density.
No Schrödinger bridge, no TRAMWAY, no RKHS — it is the simplest principled
choice and it works in the published papers.

The polynomial fitting is a constraint-satisfying smoothing step, not a separate
modelling layer. Its correctness can be directly tested by Stage 0 known-potential
controls (plant a double-well U, simulate snapshots, recover well positions and
barrier height).

## Action items resolved

- [x] Locate exact GitHub repo URL
- [x] Read the Stage 2 computation: log-density inversion + constrained polynomial
- [x] Note hard-coded assumptions (see table above)
- [x] Record findings in ADR 0002 Evidence section

## Consequences

- ADR 0002 can now be partially resolved: the baseline estimator is log-density
  inversion with constrained polynomial smoothing, translated to R.
- Stage 0 double-well controls must test: well position recovery, barrier height
  recovery, and the no-critical-points negative control (static Gaussian).
- The thinness sweep should also sweep polynomial degree and KDE bandwidth as
  secondary parameters.
- The Fokker-Planck forward propagation (SolveFP) is a separate capability —
  not required for critical-point detection, but needed for trajectory prediction
  and the Golem reward field. Flag as a future stage.
