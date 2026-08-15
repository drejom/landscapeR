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

# A reproducible run is an explicit, validated value object
config <- PipelineConfig(
  dataset = "synthetic-k1-double-well",
  analysis = analysis_specification(
    id = "double-well-coordinate",
    target_field = "x_coord",
    target_type = "continuous",
    continuous_direction = "increasing"
  ),
  strategies = list(
    Decomposer = "svd",
    DynamicsEstimator = "kde_logdensity"
  ),
  params = list(svd = list(), kde_logdensity = list())
)

# Stage 1: explicit registered SVD
svd_ctor <- get_strategy("Decomposer", "svd")
std1 <- decompose(svd_ctor(), std)@value
plot_spectrum(std1)

# Stage 2: cross-sectional calibration output only
dynamics_ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
std2 <- estimate_dynamics(dynamics_ctor(), std1)@value
plot_potential(std2)  # critical-point classifications are off by default
```

Package plots use the same publication visual grammar: quiet black, white, and
grey structure; red only for the declared focal contrast; visible missing-data
marks; and explicit categorical or continuous scales. The public helpers are
`theme_landscapeR()`, `landscapeR_palette()`, `scale_colour_landscapeR()`,
`scale_fill_landscapeR()`, and `save_landscapeR_plot()`. The save helper
defaults to a 100 mm square, 450 dpi figure; pass explicit dimensions when a
journal layout requires another aspect ratio.

Every public scientific plot carries a separate, state-derived caption. Keep
the graphic uncluttered and retrieve the corresponding publication text with
`scientific_caption(plot)`, for example:

```r
potential_plot <- plot_potential(std2)
scientific_caption(potential_plot)
```

The caption names the plotted layer or component, metadata and missingness
encodings, applicable sampling-design fields, model references or uncalibrated
diagnostics, and the scientific claim boundary.

For destructive-sampling developmental designs,
`synthetic_branching_control()` provides a disclosed two-branch visualisation
and development control. It is not validation evidence. Reproducible source
for the July 2026 informal presentation is retained under
`inst/extra/presentations/2026-07-22-ai-meeting/`; the tracked acquisition
scripts and normalized metadata for the future Pogona analysis are documented
in `data-raw/pogona/README.md`. Those local development manifests treat one
expression-matrix column as one canonical observation, expose declared tissue
pools without counting their libraries as biological replicates, and retain
unresolved registry conflicts as exclusions. They are prepared inputs for
future exploratory work, not packaged example data or validation evidence.

## Status

Active development. [`ROADMAP.md`](https://github.com/drejom/landscapeR/blob/main/ROADMAP.md)
is the single authoritative run sheet for scope, sequencing, dependencies, and
the next task. The
[pkgdown site](https://drejom.github.io/landscapeR/) presents current package
behavior and evidence, not the work schedule.

The revised K=1 acceptance API exposes audit-only version 3 and version 4
manifests and targets graphs, plus a typed result contract, operating-map
renderer, and artifact verifier. Neither retired version can execute or publish
scientific evidence because its task rows were exercised before the applicable
runner merged. Version 5 is a protocol-only refreeze with identical scientific
settings, authenticated historical RNG manifests, and explicit reservation of
the retired and development-fixture seed blocks. Its acceptance seeds remain
hidden until the protocol merge, and execution remains unavailable until a
separate version 5 runner revision is reviewed and merged. Current operating
maps are implementation fixtures, not acceptance results or sample-size
recommendations.

K=1 calibration, K=1 acceptance, and full Stage 1 evidence publish and verify
governed artifacts through one internal content-addressed seam. Each workflow
still owns its scientific validation, displayed data, caption, claim language,
and treatment of non-estimable results; the shared filesystem machinery does
not make the scientific workflows interchangeable. Publication completes and
verifies the declared payload before one atomic move to its immutable address.
Historical artifact formats remain readable and verifiable, while missing,
altered, linked, or undeclared filesystem entries are rejected.

`locate_k1_operating_domain()` can compare versioned diagnostics from a real
experiment with compatible design-aware and high-dimensional calibration
cells. It returns the exact cells supporting a point or uncertainty interval,
or typed out-of-domain evidence without extrapolating a recovery probability.
Sampling-design recovery and downstream estimability remain separate from the
corresponding high-dimensional probabilities; the package does not invent a
joint probability. Destructive designs match total retained samples as well as
per-cell counts, and the displayed signal domain uses only compatible feature
counts.
This locates operating characteristics; it does not project biological samples
into a synthetic state space or quasi-potential landscape.

In revised K=1 operating maps, red is reserved for a declared supported cell
or threshold. Continuous recovery probability uses the package's ordered,
colour-vision-robust Cividis scale. Shape continues to identify the typed cell
decision, so colour is not the only way to read the result.

Contributors should install the repository safeguards and use the documented
local/CI parity workflow in
[`docs/agents/contributor-workflow.md`](docs/agents/contributor-workflow.md).
The complete documentation authority map is in
[`docs/README.md`](docs/README.md).
Remote execution remains user-configured; the package provides a typed worker
preflight and an operational
[Gadi deployment guide](docs/agents/gadi-future-deployment.md) without choosing
scheduler or resource defaults.

## Reference

- Rockne et al. *Cancer Research* 2020 · PMID 32414754
- Frankhouser et al. *Leukemia* 2024 · PMID 38307941
