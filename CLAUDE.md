# CLAUDE.md — landscapeR

Orientation for Claude Code agents working on this package.

## What this is

`landscapeR` is an R package implementing a two-stage analysis pipeline for
multi-layer omic data:

1. **Stage 1 — Comparative decomposition** (GSVD / HO-GSVD): builds a state space
   whose axes explicitly contrast biological layers (disease vs control, temperature
   conditions, etc.), automatically separating confounders from signal.

2. **Stage 2 — Quasi-potential dynamics**: on those coordinates, fits
   U(x) = −log p(x) (log-density inversion) and reads out critical points and
   barrier heights — the tipping points and irreversibility of biological state
   transitions.

The method generalises the Rockne-Frankhouser state-transition work (published in
Cancer Research 2020, Leukemia 2024) from plain SVD to comparative GSVD/HO-GSVD,
and from MATLAB scripts to a principled, testable R package.

Three biological instantiations are planned: reptile TSD (*Pogona*), islet/diabetes
multi-omic, and CML/AML as the reference disease context.

## Architecture — read this before touching anything

The design is contract-based S4. **Nine inviolable rules** (from `decisions/`):

1. Program to interfaces (VIRTUAL classes), not implementations
2. One container flows between all stages (`StateTransitionData`)
3. Orchestration (targets) is separate from computation
4. Stage functions are pure — same input, same output, all randomness seeded
5. Validate at boundaries — typed failure, never raw exceptions
6. Configuration over modification — algorithms chosen in `PipelineConfig`, not code
7. Registry, not switch statements — `register_strategy()` / `get_strategy()`
8. Provenance is first-class — every artifact records how it was made
9. Abstract only at the joints you will actually swap; plain code inside algorithms

Violating these rules creates the multi-year maintenance traps the design explicitly
names. Don't do it for convenience.

## File map

```
R/
  00-package.R        imports
  01-schema-version.R SCHEMA_VERSION constant ("0.1.0")
  02-ground-truth.R   GroundTruth class hierarchy (SubspaceGroundTruth,
                      TopologyGroundTruth, PotentialGroundTruth)
  03-container.R      StateTransitionData (MAE subclass) + validity + migration
  04-stage-result.R   StageResult + stage_success() / stage_failure()
  05-config.R         PipelineConfig
  06-provenance.R     ProvenanceStep + record_provenance()
  07-registry.R       .registry, register_strategy(), get_strategy(), list_strategies()
  08-contracts.R      All 7 stage VIRTUAL classes + generics
  09-boundary.R       validate_boundary() — runs at every stage entry
  10-rng.R            setup_rng() — L'Ecuyer-CMRG for parallel reproducibility
  11-runner.R         run_pipeline() — sequential dev runner (not for production)

decisions/
  README.md           ADR workflow — read before making any algorithm choice
  0000-template.md    Template for new ADRs
  0001-*              Stage 1 HO-GSVD implementation (provisional)
  0002-*              Stage 2 dynamics estimator (provisional-accepted)
  0003-*              Rockne-Frankhouser reference code (accepted)
  0004-*              Package identity — eigentime vs companion (accepted)

tests/testthat/
  helper.R            empty_std() fixture
  test-container.R    StateTransitionData validity and migration
  test-registry.R     register/get/list round-trips
  test-stage-result.R StageResult construction and validation
  test-boundary.R     validate_boundary() three-way behaviour
```

## Stage implementation status

| Stage | Name | Status |
|---|---|---|
| 0 | Synthetic control ladder | Implemented: subspace and double-well controls, recovery benchmarks, and an initial Stage 1 sweep. Acceptance-threshold and rank-deficiency sweeps remain. |
| 0.5 | Signature library + archetype classifier | Deferred: unexported contract stubs only; no implementation. |
| 0.75 | Distributional fit assessment | Deferred: unexported contract stub only; no implementation. |
| 1 | Comparative decomposition (GSVD / HO-GSVD) | Implemented: multi-component `hogsvd_averaged` default and `hogsvd_prereduced` baseline, component gallery, and secondary-cohort projection. |
| 2 | Dynamics (quasi-potential) | Implemented provisionally: KDE log-density estimator and plots. Stage 0 recovery benchmarks must set ADR 0002 acceptance thresholds. |

**Complete Stage 0 validation next.** It is load-bearing: Stage 2 has no real-data
ground truth, so Stage 0 known-potential controls are the only honest validation.
ADR 0002 still has `[tbd]` acceptance thresholds that Stage 0 recovery benchmarks
must fill before the Stage 2 estimator can become fully accepted.

## ADR workflow — mandatory for algorithm choices

Every non-trivial algorithm or dependency choice needs an ADR in `decisions/`
**before code is written**. See `decisions/README.md`.

The key discipline: **define criteria before looking at results**. Do not pick
an algorithm because it exists or because it was the first one found.
Stage 0 synthetic controls are the evidence oracle — algorithm selection is
driven by recovery benchmarks, not by software availability.

## Visual landing proof — mandatory completion surface

ADR 0017 requires qualifying implementation work to land through a pull request
with inspectable visual proof. This applies to scientific behavior, public APIs,
user-visible behavior, plotting, prepared data/schema, and developer-facing
workflows.

- Fixes show rendered before/after behavior.
- New capabilities show a representative figure, table, workflow render, or
  equivalent inspectable output.
- Every proof includes a cold-reader conclusion, reproduction procedure, and
  claim status.
- Public workflow changes update current package documentation.
- Pull-request proof never substitutes for immutable scientific evidence.
- Internal-only or research/decision-only exemptions must be explicit and
  substantive; a deferred exemption expires when implementation begins.

Do not call an issue complete because tests, package checks, or Rd files pass
while this proof is missing. The development log is a concise current-status
index; the pull request is the canonical transition record.

## Key open decisions

- **ADR 0001** (Stage 1 HO-GSVD): `multiblock::hogsvd` vs Kempf rank-deficient
  HO-GSVD. Both should be registered; Stage 0 thinness sweep with rank-deficiency
  as an explicit axis decides. The rank-deficiency axis is critical — the diabetes
  genotype layer will be rank-deficient.

- **ADR 0002** (Stage 2 estimator): log-density inversion with constrained
  polynomial smoothing. Provisional-accepted. Fill in the `[tbd]` thresholds
  from Stage 0 double-well recovery to move to fully accepted.

## Key external references

- **eigentime** (`drejom/eigentime`, private): existing implementation of related
  decomposition + state-transition ideas. **Read this before implementing Stage 1
  or Stage 2** — do not duplicate work. ADR 0004 says landscapeR owns everything
  until eigentime is stable, but check what's there first.

- **Rockne-Frankhouser reference code**: `cohmathonc/CML_mRNA_state-transition`
  (public, MATLAB). CML paper; different disease but same algorithm. The Stage 2
  approach (`CML_Potentials.m`, `CML_fitStationary.m`) is what landscapeR
  generalises. Key translation: MATLAB `pdepe` → R `deSolve` + `ReacTran`.

- **Design documents** (uploaded in session, not in repo):
  - `unifiedstatetransitionmethod.md` — method concept note v0.2
  - `designspec.md` — design specification v0.1

## Dependencies

Core (Imports): `MultiAssayExperiment`, `S4Vectors`, `methods`, `digest`, `utils`,
`ks`, `deSolve`, `ReacTran`, `pracma`

Stage 1 candidate (Suggests): `multiblock`

Stage 0 optional generators (Suggests): `dyngen`, `pomp`

Stage 0.75 SBI backend (Suggests): `reticulate`

Stage 0.5 classifier (Suggests): `ranger`

## What NOT to do

- Do not add a concrete algorithm implementation without filing an ADR first
- Do not hard-code critical point locations, polynomial degree, or KDE bandwidth
  (these were the main limitations of the MATLAB reference code)
- Do not implement Stage 2 before Stage 0 `[tbd]` thresholds are filled in
- Do not use `if (method == "x")` dispatchers — use the registry
- Do not reach into `S4Vectors::metadata()` fields as if they are public API —
  only the declared `StateTransitionData` schema fields are versioned
- Do not bump `schema_version` without a migration registered for the old version
- Do not add Rcpp unless profiling identifies a specific bottleneck (deSolve's
  existing C/Fortran backends are sufficient for PDE integration)

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`drejom/landscapeR`); external PRs are not a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Multi-context layout — `CONTEXT-MAP.md` at the root points to per-context files under `context/`; shared ADRs live in `decisions/`. See `docs/agents/domain.md`.
