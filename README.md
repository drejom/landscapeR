# landscapeR

An R package for multi-layer omic state-transition analysis.

Combines **comparative decomposition** (GSVD / HO-GSVD) with **quasi-potential
dynamics** to identify tipping points and irreversibility in biological state
transitions — generalising the Frankhouser/Rockne AML work to arbitrary
multi-omic contexts.

## What it does

1. **Stage 1 — decomposition**: builds candidate state-space axes from one or
   more omic layers. Biological target and nuisance meaning is assigned only
   through the declared metadata-association, proposal, and human-confirmation
   workflow; unsupervised decomposition does not label an axis by itself.

2. **Stage 2 — Quasi-potential dynamics**: fits U(x) = −log p(x) on those
   coordinates and reads out critical points (wells, barriers) and barrier heights —
   the tipping points and irreversibility of state transitions.

Component galleries are descriptive diagnostics. The planned structured
metadata atlas/proposal workflow—not a plot heuristic—will recommend a target
biological axis for human confirmation.

## Install

**Platform:** macOS and Linux only. Windows is not supported (ADR 0014).

```r
# install.packages("pak")
pak::pak("drejom/landscapeR")
```

Bioconductor dependencies (`MultiAssayExperiment`, `S4Vectors`) are resolved
automatically via `pak`.

## Quick start

```r
library(landscapeR)

# Single-omic-layer synthetic double-well calibration control
std <- synthetic_k1_double_well_control(n = 80L, p = 100L, seed = 42L)

# Stage 1: explicit registered SVD
svd_ctor <- get_strategy("Decomposer", "svd")
std1 <- decompose(svd_ctor(), std)@value
plot_spectrum(std1)

# Stage 2: cross-sectional calibration output only
dynamics_ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
std2 <- estimate_dynamics(dynamics_ctor(), std1)@value
plot_potential(std2)  # critical-point classifications are off by default
```

## Status

Active development. [`ROADMAP.md`](https://github.com/drejom/landscapeR/blob/main/ROADMAP.md)
is the single authoritative run sheet for scope, sequencing, dependencies, and
the next task. The
[pkgdown site](https://drejom.github.io/landscapeR/) presents current package
behavior and evidence, not the work schedule.

## Reference

- Rockne et al. *Cancer Research* 2020 · PMID 32414754
- Frankhouser et al. *Leukemia* 2024 · PMID 38307941
