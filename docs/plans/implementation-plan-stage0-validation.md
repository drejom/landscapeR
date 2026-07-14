# Implementation plan — evidence-first multi-omic validation

> **Historical implementation record.** Status and sequencing in this file
> describe its originating work and are superseded for current scheduling by
> the root [`ROADMAP.md`](../../ROADMAP.md).

**Status:** approved design; implementation not started
**Date:** 2026-07-12

## Objective

Move landscapeR from a promising end-to-end prototype to an evidence-backed,
general multi-omic analysis package. The package must not make confirmatory
real-data Stage 2 claims until it has repaired its provenance and multi-omic
contracts and passed the frozen Stage 0 control ladder.

This plan implements the accepted decisions in ADRs 0002 and 0006–0009. It
does not implement a longitudinal estimator, a 2D/bifurcation estimator, or
missing-block factorisation.

## Non-negotiable stop rule

Do not add new Stage 2 capabilities or make confirmatory real-data claims until:

1. stage provenance persists in `StateTransitionData`;
2. Stage 1 supports the ADR 0009 alignment/projection contract;
3. the Stage 0 positive and negative control ladder passes under a frozen
   multi-seed protocol; and
4. ADR 0002 is updated with finalized thresholds and pass rates.

## Phase 0 — Preserve the decision record

**Goal:** Make the approved scientific and architectural policy reviewable.

- Keep ADRs 0006–0009, the ADR 0002 amendment, and context/glossary updates as
  a documentation-only change set.
- Keep Issue #5 deferred: it now has an agreed scientific role but no concrete
  Stage 0.5/0.75 implementation.
- Keep Issue #22 deferred: incomplete observations may not contribute to joint
  Stage 1 fitting or Stage 2 until projection-only use has dedicated controls.

**Exit criteria**

- Documentation diff is reviewed and has no formatting errors.
- ADR 0001, 0002, 0006–0009 and Issues #22–#24 form a coherent decision chain.

## Phase 1 — Repair provenance (Issue #23)

**Goal:** Make every artifact auditable before it is used as evidence.

1. Define one meaning for `StageResult@provenance`: a list of
   `ProvenanceStep` records, never an updated data container.
2. Update every stage to return the `StateTransitionData` returned by
   `record_provenance()`.
3. Ensure `run_pipeline()` preserves the returned container through every
   successful stage.
4. Test direct Stage 1/Stage 2 calls and the runner: each successful stage
   appends exactly one `ProvenanceStep`.

**Exit criteria**

- `StateTransitionData@provenance` is the authoritative ordered audit trail.
- Tests prove no `StateTransitionData` objects appear in
  `StageResult@provenance`.

## Phase 2 — Resolve the heterogeneous-feature Stage 1 algorithm

**Decision gate — no production Stage 1 rewrite before this is accepted.**

ADR 0009 establishes that layers have different feature spaces and share
matched biological observations. The existing common-feature V-averaging
algorithm cannot simply be wrapped in a list of loadings.

1. Amend ADR 0001 with candidate algorithms that construct shared structure in
   sample space while retaining layer-specific feature loadings.
2. Define before benchmarking:
   - component/sign/rotation alignment between layers;
   - weighting and component ordering;
   - per-layer projection loadings;
   - recovery metrics for matched sample-space truth and layer-specific loading
     truth.
3. Build only the small synthetic/prototype experiments needed to compare
   candidates on noiseless recovery, rank deficiency, realistic dimensions, and
   timing.
4. Register the chosen and baseline strategies; update ADR 0001 only from the
   resulting frozen comparison evidence.

**Exit criteria**

- ADR 0001 names a mathematically specified, benchmark-selected Stage 1
  algorithm for heterogeneous feature spaces.
- The recovery metric no longer assumes a universal gene-loading vector.

## Phase 3 — Versioned data and analysis declarations (ADRs 0006 and 0008)

**Goal:** Make the scientific scope explicit and machine-checkable.

1. Add versioned `SamplingDesign` support to `StateTransitionData`:
   cross-sectional or longitudinal, with longitudinal subject/time column
   references.
2. Bump the schema once with registered migration(s). Legacy objects migrate to
   explicit `unspecified` sampling design and cannot enter Stage 2 until
   declared.
3. Add a compact `analysis` specification to `PipelineConfig` for one
   target-axis run:
   - target metadata field or explicit manual component;
   - nuisance fields;
   - optional orientation anchor;
   - primary-confirmatory or exploratory intent.
4. Extend boundary validation and provenance. Required design fields with
   missing values produce recorded cohort exclusions; diagnostic fields report
   available-case counts only.
5. Add a contract-level estimator capability for supported sampling designs.
   `kde_logdensity` supports cross-sectional analysis only; longitudinal
   support remains a future registered strategy.
6. Add machine-readable Stage 2 claim status. `no-transition` and
   `ineligible` are successful outcomes, not computational failures.

**Exit criteria**

- Declarations are validated, migrated, and carried in provenance.
- Current KDE refuses incompatible longitudinal input with a typed failure.
- One target biological axis is explicit per pipeline run.

## Phase 4 — Correct Stage 1 alignment and projection (Issue #24 / ADR 0009)

**Goal:** Make genuine multi-omic fitting and discovery/confirmation projection
safe.

1. Implement one shared Stage 1 preparation path for both strategies.
   - Use `MultiAssayExperiment` sample mapping and canonical biological IDs.
   - Form the complete paired cohort; reject ambiguity, duplicates, and too few
     observations.
   - Record exclusions and missingness patterns; never impute or zero-fill an
     omic block.
2. Redesign `DecompositionResult` around named layer-specific loading matrices,
   shared matched-sample coordinates, per-layer preprocessing references, and
   alignment metadata.
3. Replace common-loading accessors and update plots, Stage 2 fixtures, and
   synthetic recovery code.
4. Redesign `project_into()`.
   - Require declared unique feature IDs in per-assay `rowData`.
   - Match/reorder features by ID, reject unmatched required features.
   - Apply discovery-fitted centring/scaling; never independently centre the
     confirmation cohort.
   - Mark output as `projected`; Stage 2 must not pool it under Issue #22.
   - Return typed failure for invalid input rather than `stop()` or clipped
     layer indices.
5. Migrate old Stage 1 results safely: invalidate unreconstructable legacy
   artifacts and require re-running Stage 1.

**Exit criteria**

- Heterogeneous feature counts and assay/feature permutations are safe.
- Projection is feature-ID mapped, reference-preprocessed, and provenance
  complete.
- Tests cover alignment ambiguity, complete-case exclusions, feature mismatch,
  and projection recovery.

## Phase 5 — Build the Stage 0 evidence infrastructure

**Goal:** Make benchmark results reproducible and reviewable without bundling
large generated matrices.

1. Define a versioned benchmark protocol/manifest before aggregate runs:
   generator version and digest, parameter grid, seeds, metrics, calibration
   versus holdout replicate split, pass-rate rule, environment, and artifact
   hash.
2. Store compact one-row-per-replicate benchmark tables and frozen figures.
   Regenerate synthetic matrices from generator specification and seed manifest.
3. Implement an executable Stage 0 validation vignette that renders frozen
   evidence tables/figures, the protocol digest, limits, and claim scope.
   Keep `development-log.Rmd` as a living progress document, not acceptance
   evidence.
4. Keep full sweeps out of ordinary PR checks; retain small deterministic smoke
   examples and run full evidence refreshes deliberately.

**Exit criteria**

- Every benchmark result is traceable to code, configuration, seed, and
  environment.
- Changing a generator/configuration creates a new artifact version and ADR
  amendment rather than overwriting evidence.

## Phase 6 — Execute the Stage 0 ladder in order

**Goal:** Establish recovery, false-positive, and applicability evidence.

1. **Estimator-only controls:** multi-seed double-well then three-well recovery
   across sample size, separation, diffusion/noise, and fixed candidate
   bandwidth/smoothing rules.
2. **Estimator-only negatives:** unimodal/continuous controls; require valid
   no-transition conclusions and measure spurious topology rate.
3. **Stage 1-only controls:** sample-space recovery across signal, thinness,
   layer count, rank deficiency, heterogeneous feature spaces, and realistic
   scale/noise differences.
4. **End-to-end positives:** multi-omic controls whose planted target
   biological axis carries known quasi-potential coordinates.
5. **Confounder separation:** a stronger shared confounder makes the target
   non-dominant; selection must find the predeclared target before Stage 2.
6. **End-to-end negatives:** no target, discordant layers, unimodal topology,
   and branching/multi-axis cases. Never flatten an unsupported case into a
   one-dimensional confirmatory conclusion.
7. **Missingness/alignment controls:** random and condition/time-associated
   masking, complete-paired fitting, feature/sample permutations, and
   projection recovery. Projected incomplete observations remain excluded from
   Stage 2.
8. **Domain-grounded controls:** AML, *Pogona*, and diabetes-like observation
   structures after the generic mathematical controls pass.

**Exit criteria**

- Finalize recovery and false-positive thresholds, minimum requirements, and
  pass rates from independent holdout replicates.
- Amend ADR 0002 from provisional-accepted to accepted only if the frozen
  protocol passes.

## Phase 7 — Applicability gate and real-data evidence

**Goal:** Prevent unsupported real-data claims.

1. Implement Stage 0.5/0.75 only after Phase 6 establishes the reference
   controls, following ADR 0010: compare a transparent signature-distance
   baseline with an optional `ranger` candidate on held-out calibration;
   enforce abstention and false-eligibility control. Build archetypes for
   ordered one-dimensional, single-well/continuous, branching, and multi-axis
   geometry.
2. Make Stage 0.5 classification and Stage 0.75 fit assessment required for
   confirmatory real-data Stage 2 claims (ADR 0007).
3. Add data manifests for real datasets: source/access, checksum or version,
   inclusion/exclusion IDs, preprocessing reference, analysis-spec digest, and
   benchmark version.
4. Add separate real-data vignettes:
   - discovery cohort: predeclared target/nuisance/orientation and fixed config;
   - confirmation cohort: feature-ID-safe projection and frozen analysis;
   - explicit claim status, bootstrap stability, diagnostic associations, and
     limits.

**Exit criteria**

- Real-data results are labelled confirmatory only when all evidence gates pass.
- Results without a confirmation cohort or applicability evidence are marked
  exploratory.

## Explicitly deferred work

- Longitudinal Stage 2 estimator, diffusion, directionality, or time-to-
  transition: new strategy, ADR, and longitudinal Stage 0 ladder required.
- Two-dimensional/branching estimator for *Pogona*: new strategy, ADR, and
  bifurcation-control ladder required.
- Missing-block joint factorisation or using projected incomplete observations
  in Stage 2: Issue #22 after dedicated missingness evidence.
- Assay-specific preprocessing and technical-replicate aggregation: upstream
  responsibilities, retained only as input provenance.

## Validation at every phase

- Focused new testthat tests first, then full package tests.
- `R CMD build` followed by `R CMD check` on the tarball (not only a working
  directory check).
- ADR coverage and registry-compliance scripts.
- `git diff --check`.
- Vignette smoke render for changed evidence interfaces; deliberate full
  benchmark refresh for evidence changes.
