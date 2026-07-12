# landscapeR

An R package for multi-layer omic state-transition analysis.

Combines **comparative decomposition** (GSVD / HO-GSVD) with **quasi-potential
dynamics** to identify tipping points and irreversibility in biological state
transitions — generalising the Frankhouser/Rockne AML work to arbitrary
multi-omic contexts.

## What it does

1. **Stage 1 — Comparative decomposition**: builds a shared state space across
   omic layers whose axes explicitly contrast conditions (disease vs control,
   temperature, genotype). Batch effects and confounders are separated from
   biological signal by design.

2. **Stage 2 — Quasi-potential dynamics**: fits U(x) = −log p(x) on those
   coordinates and reads out critical points (wells, barriers) and barrier heights —
   the tipping points and irreversibility of state transitions.

A gallery diagnostic (`plot_components()`) identifies which component carrying
the state-transition signal without requiring prior knowledge of the biology.

## Install

```r
# install.packages("pak")
pak::pak("drejom/landscapeR")
```

Bioconductor dependencies (`MultiAssayExperiment`, `S4Vectors`) are resolved
automatically via `pak`.

## Quick start

```r
library(landscapeR)

# Synthetic double-well ground truth
std  <- synthetic_potential_control(n = 80L, seed = 42L)

# Stage 1
ctor  <- get_strategy("Decomposer", "hogsvd_averaged")
std1  <- decompose(ctor(), std)@value
plot_components(std1, colour_by = "group")

# Stage 2
dctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
std2  <- estimate_dynamics(dctor(), std1)@value
plot_potential(std2)
```

## Status

Active development — see the [pkgdown site](https://drejom.github.io/landscapeR/)
for the current development log and roadmap.

## Reference

Frankhouser et al. *Cancer Research* 2020 · PMID 32414754  
Frankhouser et al. *Leukemia* 2024 · PMID 38307941