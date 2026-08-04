# Execution and reproducibility

ADR 0018 defines three computation tiers. `inspect` contains point estimates
only and is exploratory. `standard` resamples biological units while holding
the fitted state space fixed and supports conditional uncertainty only.
`evidence` reruns every applicable fitted stage and is merely eligible for
confirmatory use after the separate scientific gates pass.
Legacy serialized atlases using `analytic-unadjusted`, `analytic-adjusted`, or
`standard-resampled` remain readable, but newly constructed artifacts emit only
the three governed tiers above.

Every stochastic workflow declares one run seed. The package derives a child
L'Ecuyer-CMRG stream from that seed plus each stable task identity using the
recorded `sha256-lecuyer-state-v1` scheme. Task streams therefore do not
depend on worker count, scheduling, chunking, or completion order. Typed
repetition results retain every requested task in the denominator and record
completed tasks, stable failure codes, tier, seed scheme, task identities,
child stream states, and a content digest. Stream collisions are rejected.

Package functions use `future.apply` but never call `future::plan()` or change
`future.*` options. Users select sequential, multisession, cluster, or remote
backends outside the package. Outer `targets` or `crew` tasks can pass
`sequential_internal = TRUE` to `associate_metadata()`; the repetition seam
then submits the complete internal task set as one future, where its elements
execute sequentially, avoiding nested worker multiplication without changing
the global plan. Optional `future_scheduling` is explicit;
`NULL` leaves future.apply scheduling unchanged rather than freezing a package
default.

Sampling adapters remain responsible for exchangeability and draw
construction. The shared execution seam owns only repetition, RNG derivation,
failure normalization, accounting, and typed partial results. Current adapters
include cross-sectional biological-observation bootstrap, independent
condition-by-time bootstrap, repeated complete-subject trajectory bootstrap,
the corresponding complete-search permutation procedures, and Stage 1 paired
calibration and per-stratum median holdout summaries. Stage 1 summary reports
retain typed execution results and serialized-payload measurements alongside
their scientific intervals. Permutation evidence likewise retains its typed
execution result alongside the design-specific resampling account. No worker,
chunk, or resample-count default is frozen; serialization and scheduling must
be benchmarked on the eventual workload before such a default is proposed.
