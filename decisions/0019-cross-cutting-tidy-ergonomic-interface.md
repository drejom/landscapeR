# 0019 — Tidy ergonomic interface over Bioconductor containers

**Stage:** cross-cutting
**Status:** accepted
**Date:** 2026-07-13

## Context

landscapeR's current implementation is base-R-heavy for table construction and
iteration, while its public container model is S4/Bioconductor and its graphics
already use ggplot2. No ADR selected a base-R-only style. The current pattern
appears to reflect dependency minimisation, Bioconductor conventions, and
incremental implementation rather than a deliberate long-term usability policy.

The package is becoming a sophisticated human-in-the-loop scientific workflow:
users inspect metadata associations, assign scientific roles, compare raw and
hypothesis-conditioned evidence, confirm components, and inspect fitted
landscapes. Human readability and reviewability are therefore correctness
concerns, not cosmetic preferences. The planned Shiny interface will also need
structured tabular outputs rather than plotting functions that privately hold
computed scores.

The tidyomics ecosystem provides a relevant precedent. Packages including
`tidySummarizedExperiment`, `tidySingleCellExperiment`, and `tidybulk` retain
canonical Bioconductor containers while exposing dplyr/tidyr/ggplot-compatible
interfaces. There is no equivalently mature tidy `MultiAssayExperiment` bridge
that resolves landscapeR's cross-layer `sampleMap` semantics automatically.

## Options considered

| Option | Source / reference | Key property | Disqualifier or concern |
|---|---|---|---|
| Preserve base-R-only implementation | Current code | Small dependency set | Nested `lapply`/`vapply`/`do.call` table code can be hard to review; no documented policy supports the restriction |
| Import the `tidyverse` or `tidyomics` meta-package | tidyverse/tidyomics | Broad ergonomic API immediately available | Large undifferentiated dependency surface and functionality not needed by the package core |
| Implement dplyr verbs directly on `StateTransitionData` | tidySummarizedExperiment precedent | Fluent manipulation of the main container | Ambiguous semantics across MAE layers, sample maps, incomplete observations, and assay features |
| Keep numerical/Bioconductor core and add focused tidy dependencies plus explicit tidy accessors | tidyomics design principle | Human-readable tables and plots without weakening container or matrix contracts | Requires a deliberate boundary and incremental interface work |

## Criteria

- Scientific containers and matrix algebra retain their validated semantics.
- Metadata, evidence tables, and plotting data are readable and reviewable by
  R users comfortable with tidy workflows.
- Large assay matrices are not accidentally materialised as feature-by-sample
  long tables.
- Cross-layer sample and feature semantics remain explicit.
- Result objects are structured, serializable, testable, and Shiny-ready.
- Dependencies are well-supported and added for concrete use rather than by
  convenience alone.
- Existing stable numerical code is not rewritten without scientific or
  maintenance benefit.
- The interface can interoperate with upstream tidyomics preparation workflows.

## Evidence

The tidyomics documentation demonstrates a maintained Bioconductor pattern:
retain `SummarizedExperiment`/`SingleCellExperiment` as the canonical object and
provide tidy views and verbs for manipulation and plotting. `tidybulk` shows
that domain-specific transcriptomic analyses can remain modular and readable in
this style.

The pattern does not directly solve `MultiAssayExperiment`: a verb such as
`filter(std, condition == "CM")` is ambiguous unless the package specifies how
primary observations, assay columns, `sampleMap`, and incomplete layers change
together. The existing `plot_components()` metadata-level bug also demonstrates
that explicit, testable table boundaries matter more than syntactic conversion
alone.

No performance benchmark supports converting dense assay matrices to tibbles
for numerical kernels. SVD/GSVD and related operations should continue to use
matrix representations and BLAS/LAPACK-backed operations.

## Decision

**Chosen:** retain the S4/Bioconductor and matrix computational core while
adopting a focused tidy interface for metadata, result tables, provenance, and
graphics, inspired by tidyomics.

### Boundary

- `StateTransitionData`, `MultiAssayExperiment`, `SummarizedExperiment`,
  `S4Vectors::DataFrame`, and matrix assays remain canonical scientific
  representations.
- Dense/sparse numerical kernels operate on matrices; tidy tools are not a
  replacement for SVD, GSVD, dense matrix multiplication, or sparse matrix
  methods.
- Metadata-association, component-proposal, evidence-summary, critical-point,
  and plotting tables may use tibble/dplyr/tidyr/purrr internally and expose
  explicit tidy accessors or `as_tibble()` methods.
- Initial accessors have unambiguous row semantics, for example sample metadata,
  component coordinates, component loadings, association rows, proposal ranks,
  potential curves, and critical points.
- Assay-wide long-table materialisation is explicit and opt-in, never an
  automatic intermediate.
- Direct dplyr methods on `StateTransitionData` are deferred until a separate
  decision specifies MAE sample-map, layer, feature, provenance, and incomplete-
  observation semantics.

### Dependencies and style

- Import individual, concretely used packages (`dplyr`, `tidyr`, `tibble`,
  `purrr`) rather than the `tidyverse` or `tidyomics` meta-package.
- Add each dependency only with the first implementation that uses it; this ADR
  does not add unused Imports pre-emptively.
- Continue to use ggplot2 for all package graphics; do not add a parallel base-
  graphics API.
- Prefer short, named transformations over deeply nested apply code or very long
  pipe chains. Use package-safe tidy evaluation such as `.data[[field]]` for
  dynamic columns.
- Convert between `S4Vectors::DataFrame` and tibble only at named boundaries.
- Existing base-R numerical and table code is not rewritten wholesale. Refactor
  opportunistically when implementing or repairing the owning module, with
  tests preserving behaviour.

### Staging

The complete ergonomic interface is deliberately deferred until the scientific
contracts it presents are stable. It must not delay the K=1 Stage 0 ladder,
metadata-association scientific design, Stage 1 v3 evidence, or other evidence
gates. New scientific objects are nevertheless designed now as structured,
serializable outputs so a later tidy and Shiny layer can consume them without
reimplementing scientific logic.

Upstream interoperability with `tidybulk` or `tidySummarizedExperiment` should
be documented in a later vignette; landscapeR does not need to depend on those
packages unless a concrete integration requires it.

## Consequences

- New human-facing table code may be substantially clearer at the cost of a
  modest, focused dependency increase.
- The package remains recognisably Bioconductor-compatible rather than replacing
  its containers with tibbles.
- A future Shiny application can render package-owned objects and ggplot output.
- Users can prepare individual assays with tidyomics tools upstream and pass the
  resulting Bioconductor objects into landscapeR.
- Direct tidy manipulation of the full multi-assay container remains unavailable
  until its semantics are safe and explicit.
- Review standards should assess semantic clarity and object boundaries, not
  enforce base R or tidyverse as an ideology.

## Review trigger

Revisit when the scientific result contracts are stable enough for the full
human-facing interface, when a maintained tidy `MultiAssayExperiment` bridge
with compatible semantics appears, or when profiling demonstrates that a tidy
tabular boundary creates material memory/runtime costs in a real workflow.
