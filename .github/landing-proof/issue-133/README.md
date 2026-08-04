# Issue #133 landing proof: Stage 1 summary futures

## Claim boundary

This is execution evidence only. It does not recalibrate Stage 1, change a
scientific threshold, accept a decomposition method, or alter the frozen v2
evidence artifact.

## Backend equivalence

The paired calibration and median holdout summaries were each run for the
frozen 10,000 bootstrap repetitions under `future::sequential` and under
`future::multisession` with two local workers. Both backends returned bytewise
identical intervals, accounting, task identities, RNG provenance, and execution
digests.

| Summary path | Requested | Completed | Failed | Sequential digest equals multisession digest |
|---|---:|---:|---:|---|
| Paired calibration mean | 10,000 | 10,000 | 0 | yes |
| Per-stratum holdout median | 10,000 | 10,000 | 0 | yes |

Stable task identities include the summary scope and replicate index. The
execution record retains the declared run seed, `L'Ecuyer-CMRG` RNG kind,
`sha256-lecuyer-state-v1` derivation scheme, and one child stream per task.

## Runtime and serialization

Measurements below were taken on the development Mac with one CPU allocated to
the R process; two local workers were enabled explicitly for the comparison.
They describe this small proof payload, not a general performance promise.

| Summary path | Sequential (s) | Multisession, 2 workers (s) | Tasks payload (bytes) | Task IDs (bytes) | Shared input (bytes) |
|---|---:|---:|---:|---:|---:|
| Paired calibration mean | 0.744 | 6.414 | 120,031 | 710,031 | 164 |
| Per-stratum holdout median | 0.771 | 6.440 | 120,031 | 730,031 | 63 |

The observed local multisession overhead is larger than the computation saved.
Accordingly, this change does not set a package plan, worker count, chunk size,
or scheduling default. The user-selected future backend remains authoritative.

## Frozen-artifact check

The committed `stage1-heterogeneous-v2` artifact still verifies at its existing
content address and retains its existing manifest, estimates, thresholds, and
failed holdout decision. Newly executed reports add execution and serialization
records without rewriting that artifact.

## Reproduction

```r
future::plan(future::sequential)
sequential <- landscapeR:::.stage1_paired_bootstrap(exact, metric, rules)

future::plan(future::multisession, workers = 2L)
parallel <- landscapeR:::.stage1_paired_bootstrap(exact, metric, rules)

stopifnot(identical(sequential, parallel))
```

The installed-package backend-equivalence test repeats this contract for both
summary paths at 10,000 repetitions. The ordinary development-source test runs
the sequential half and skips only the multisession half because source-loaded
workers cannot import an uninstalled package reliably.
