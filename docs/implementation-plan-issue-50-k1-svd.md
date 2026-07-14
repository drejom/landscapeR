# Implementation plan — issue #50 K=1 SVD foundation

## Fixed scope

Implement only issue #50:

1. permit K=1 synthetic generation without changing K≥2 behaviour;
2. register explicit `Decomposer:svd`;
3. typed-fail `svd` for any omic-layer count other than one;
4. return the common `DecompositionResult` and truthful `svd` provenance;
5. add deterministic K=1 subspace-recovery tests;
6. add a generic cross-sectional K=1 double-well calibration harness.

No thresholds, acceptance/holdout evidence, AML longitudinal control, real data, atlas/proposal, or HO-GSVD fallback.

## Pre-agreed public seams

The originating issue and ADR define these test seams:

- `synthetic_control(..., K = 1L)` → valid single-omic-layer `StateTransitionData` with planted ground truth;
- `get_strategy("Decomposer", "svd")` → registered constructor;
- `decompose(svd(), std)` → successful common `DecompositionResult` for exactly one omic layer;
- `decompose(svd(), multi_omic_layer_std)` → typed `StageResult` failure;
- returned provenance identifies `Decomposer:svd` through the normal pipeline boundary;
- public K=1 calibration helper → structured, labelled non-evidentiary recovery output using known double-well truth;
- implementing pull request → before/after or representative visual landing proof, a cold-reader conclusion, reproduction procedure, and calibration-only claim status;
- current development documentation → direct registered-SVD workflow rather than the obsolete duplicated-omic-layer workaround.

Tests use planted ground truth and independent subspace metrics rather than implementation internals. The pull request is the visual transition seam under ADR 0017; it does not replace independent acceptance evidence.

## TDD slices

1. RED/GREEN: K=1 synthetic constructor validity and K≥2 regression.
2. RED/GREEN: registered `svd` strategy succeeds for K=1 and exposes expected result shape.
3. RED/GREEN: `svd` typed-fails for K≥2; existing HO-GSVD still rejects K=1.
4. RED/GREEN: deterministic planted-subspace recovery and seeded reproducibility.
5. RED/GREEN: generic cross-sectional K=1 double-well calibration helper returns labelled calibration metrics and never an acceptance judgement.
6. Verify focused tests, full test suite, package build/check, diff checks, and issue acceptance mapping.
7. Render and visually inspect the current K=1 workflow in pkgdown; record the full landing proof in the pull request.
8. Commit implementation, audit every requirement, then run two-axis code review against the fixed point before implementation.

## Completion evidence

- K=1 constructor, explicit `svd` registry strategy, exact-one-omic-layer typed failure, truthful provenance, deterministic subspace recovery, and calibration-only double-well harness are implemented.
- Focused tests: 111 passed.
- Full test suite: 454 passed.
- `R CMD check --no-manual`: code, Rd documentation, examples, package tests, and package-included vignettes passed. Local check reports one environment warning because the installed `MultiAssayExperiment` was built under R 4.5.3 while local R is 4.5.2, plus the already documented long benchmark-path NOTE. The living development log is excluded from `R CMD check` and is verified separately by the pkgdown build and rendered visual review.
- Two-axis review found and prompted fixes for small-sample SVD rank truncation, beta-scaled quasi-potential truth, calibration configuration/provenance, duplicated recovery metrics, typed generator validation, and the previously omitted exact-stationary sampler ADR amendment.
- No acceptance thresholds, real data, AML longitudinal control, or HO-GSVD fallback were added.
- **Correction under #68:** the initial completion audit omitted visual landing proof and left the public development log on the obsolete duplicated-omic-layer workaround. #50 is not complete until its branch PR contains the proof packet, the current documentation is rendered and inspected, and CI passes.
