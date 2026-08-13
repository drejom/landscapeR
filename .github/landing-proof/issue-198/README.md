# Issue #198 landing proof: shared K=1 calibration publication seam

## Cold-reader conclusion

The independent-time, repeated-subject, and high-dimensional K=1 calibration
modules now use one internal implementation for content-addressed publication
and verification. Each module still owns its scientific validator, displayed
data, caption, context, and treatment of non-estimable results. Public function
names and the governed artifact layout are unchanged.

## Before and after

| Concern | Before | After |
|---|---|---|
| Governed file list | Repeated across three calibration modules | Declared once in the shared artifact seam |
| Manifest and digest verification | Repeated module-specific implementations | One shared verifier with module-specific typed messages |
| Derivative replay | Repeated comparison code | Shared replay using each module's plotter and exact display-data adapter |
| Atomic publication | Repeated staging and move logic | One shared staging, content-address, and atomic-move implementation |
| Scientific validation | Owned by each module | Still owned by each module |
| High-dimensional source layout | Policy, generation, assessment, rendering, publication, and orchestration in one file | Regime and generator policy separated from assessment, rendering, publication, and orchestration |

## Artifact replay

| Calibration path | Publish and verify exercised | Assessment digest retained | Exact displayed derivative replayed |
|---|---:|---:|---:|
| Independent destructive time course | yes | yes | yes |
| Repeated-subject time course | yes | yes | yes |
| High-dimensional signal regime | yes | yes | yes |

Malformed manifests, unreadable RDS payloads, readable but structurally invalid
environment envelopes, undeclared files, changed derivatives, invalid runtime
identity, and failed atomic moves are rejected through package-owned typed
conditions.

## Reproduction

From the repository root, run:

```sh
Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-k1-independent-time-course-calibration.R", stop_on_failure = TRUE); testthat::test_file("tests/testthat/test-k1-repeated-subject-calibration.R", stop_on_failure = TRUE); testthat::test_file("tests/testthat/test-k1-high-dimensional-regimes.R", stop_on_failure = TRUE)'
```

Inspect `docs/architecture/k1-calibration-modules.md` for the resulting module
boundaries and `R/13m-stage0-k1-calibration-artifacts.R` for the shared seam.

## Claim boundary

This is implementation and architecture proof. It does not change a scientific
algorithm, threshold, public API, serialized evidence contract, or accepted
operating region.
