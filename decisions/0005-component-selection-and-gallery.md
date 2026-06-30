# 0005 — Component selection: multi-component Stage 1 output and component plots

**Stage:** 1 / cross-cutting
**Status:** accepted
**Date:** 2026-06-29

## Context

Rockne2020 and Frankhouser2022/2024 all use SVD/PCA and then select a specific
component as the "disease axis" by manual inspection — picking whichever PC
separates disease from control, or correlates best with a known marker (Kit
expression). This is valid for a single published analysis but is not
reproducible or generalisable: it requires a-priori knowledge of which PC
matters and is not transferable to a new biological system.

The current landscapeR Stage 1 returns only `V_star` (the dominant shared gene
axis) and `coords` (a single coordinate per layer per sample). This is
structurally incapable of exposing the disease axis when it is not the dominant
component — which is common:

- In Rockne2020: PC1 (47% variance) is age/time; PC2 (11% variance) is leukemia.
  The dominant component is confounded with age; the disease axis is second.
- In the 2016 training cohort: batch and timepoint are perfectly confounded,
  so the dominant component captures the sequencing batch / age axis.
- In the 2018 validation cohort (properly randomised): the dominant component
  may well be the disease axis — but we cannot assume that in general.

landscapeR's goal is to make this sophisticated analysis accessible without
requiring the user to know in advance which component is biologically relevant.
The correct solution is:

1. Return **k components** from Stage 1 (not just the first)
2. Provide a **component plots** (`plot_components()`) that shows each component's
   separation by a user-supplied metadata column, ranked by a separation score
3. Stage 2 takes a `component` parameter (default: auto-selected)

### The projection convention (from Rockne2020)

The paper's validation protocol is:
1. SVD on the primary (better-quality) cohort → V* loadings
2. Project the secondary cohort: `X_secondary · V*` → coordinates in same space
3. Run Stage 2 on the primary cohort's coordinates; use projected secondary as
   confirmation that signal survives

For the AML data this means: **2018 = primary** (properly randomised, clean
signal); **2016 = secondary** (batch-confounded, projected in as stress-test).
The 2016 batch confounding is the point of the exercise — if the disease axis
survives projection despite confounding, that strengthens the biological claim.

## Options considered

| Option | Key property | Assessment |
|---|---|---|
| Return all k components, user selects | Maximally transparent; separates computation from interpretation | **Selected** |
| Auto-select by condition correlation at fit time | Convenient but requires condition column at Stage 1 | Couples decomposition to metadata — violates pure-function contract |
| Return only top component (current) | Simple | Misses disease axis whenever age/batch dominates σ₁ |
| Return top component + flag if correlation with metadata is low | Compromise | Still hides the structure from the user |

## Criteria

1. **Observability** — the user can see which component corresponds to disease
   without requiring a-priori knowledge
2. **Separation without pre-selection** — Stage 1 computation does not depend
   on the condition label; component selection happens at inspection time, not
   fit time (pure function contract preserved)
3. **Backwards compatibility** — downstream code that uses `metadata()$stage1$coords`
   as a list of per-layer coordinate vectors can still work; we extend, not replace
4. **Projection support** — secondary cohorts can be projected into the primary
   state-space to confirm signal survives
5. **Component plots actionability** — the plot must make the right component obvious to
   a biologist, not just show raw numbers

## Evidence

From the AML 2016 training data (this session):

| Component | r(coord, condition) | r(coord, timepoint) | Interpretation |
|-----------|---------------------|---------------------|----------------|
| PC1       | −0.17               | 0.81                | Age / batch    |
| PC2       | 0.53                | −0.07               | Disease axis   |

From the AML 2018 validation data projected into 2016 training V*:

| Component | r(coord, condition) |
|-----------|---------------------|
| PC1       | 0.19                |
| PC2       | 0.46                |

PC2 density for 2018 CM samples shows visible bimodality (healthy peak ~−40,
disease shoulder / tail toward positive) matching the double-well landscape
reported in Rockne2020. This bimodality is not visible in PC1.

## Decision

**Stage 1 returns `k_components` components (default k=6). `metadata()$stage1`
gains `coords_k` (list of k coordinate matrices, n×k per layer), `V_k` (gene
loading matrix p×k), and `sigma_k` (k singular values per layer). The existing
`V_star` and `coords` fields are preserved as aliases pointing to component 1
for backwards compatibility.**

**`plot_components(std, colour_by, n_components=6)` is added as a component plots
showing, for each component, the per-condition distribution and a separation
score (η² for categorical, r² for continuous). Components are sorted
highest-separation-first.**

**`estimate_dynamics()` gains a `component` parameter (integer, default 1).
When running on real data the user inspects the component plots and passes the relevant
component number explicitly.**

**`project_into(std_primary, std_secondary)` is added as a utility that
computes `X_secondary · V*_primary` and returns the secondary object with
projected coordinates stored in `metadata()$stage1$coords_projected`.**

Rationale: this preserves the pure-function contract (Stage 1 computation does
not see condition labels), gives the user full observability, and matches the
Rockne2020 validation protocol without hard-coding a component index.

## Consequences

- `metadata()$stage1` schema changes — `SCHEMA_VERSION` must bump and a
  migration registered (old objects set `coords_k = list(coords)`,
  `V_k = matrix(V_star, ncol=1)`)
- `plot_components()` requires ggplot2 + a metadata column name — both
  already available
- Stage 2 `component=1` default means existing tests pass unchanged; synthetic
  double-well tests already use a single component
- `project_into()` is a pure function (no side-effects on the primary object);
  it only writes to the secondary object's metadata
- The component plots becomes the expected first step after Stage 1 on any new
  dataset — this should be documented in the vignette workflow

## Review trigger

- If k=6 components is consistently insufficient (signal in component >6) for
  a new biological system, expose k as a parameter in `PipelineConfig`
- If auto-selection is requested by users, add it as an opt-in `auto_select_by`
  parameter that records the selection rationale in provenance — but do not
  make it the default (manual selection after component plots inspection is the
  scientifically honest path)
