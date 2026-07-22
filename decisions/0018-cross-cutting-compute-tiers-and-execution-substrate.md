# 0018 — Compute tiers and execution substrate

**Stage:** cross-cutting
**Status:** accepted
**Date:** 2026-07-13

## Context

landscapeR needs repeated computation at several scales: interactive component
inspection, subject-aware bootstrap uncertainty, full Stage 0 evidence grids,
and end-to-end resampling that reruns Stage 1 and Stage 2. The same scientific
functions must run sequentially on a modest machine, in parallel on a multicore
macOS/Linux workstation, and through a scheduler on HPC.

The existing Stage 1 evidence runner proved that checkpointed parallel work is
necessary: protocol v2 comprised 40,960 tasks and completed remotely in 2 h 41 m.
It currently uses bespoke `parallel::mclapply()` execution and local checkpoint
files. That implementation is useful evidence but is not a general execution
substrate for interactive analyses, future Shiny use, or scheduler-backed HPC.

Computational shortcuts must also be scientifically explicit. A quick point
estimate, uncertainty conditional on a fixed decomposition, and uncertainty
that reruns the whole fitted pipeline answer different questions and must not
share an undifferentiated `bootstrap = TRUE` label.

## Options considered

| Option | Source / reference | Key property | Disqualifier or concern |
|---|---|---|---|
| Keep bespoke `mclapply()` and checkpoint orchestration | Current Stage 1 runner | Proven on macOS/Linux | Fork-specific, package-owned worker policy, and difficult to extend across local/HPC contexts |
| Use `future`/`future.apply` for all orchestration | future ecosystem | User-selected sequential, local, remote, and scheduler backends with reproducible RNG | Does not itself provide a durable workflow graph, invalidation, or evidence-pipeline cache |
| Use `crew` directly inside scientific functions | crew | Distributed task queue, auto-scaling, cluster plugins | Couples scientific runtime contracts to orchestration and worker lifecycle |
| Use `future.apply` for reusable repeated computation and `targets` + `crew` for full workflows | future, targets, crew | Separates computation from orchestration while supporting interactive/local/HPC execution | Requires explicit prevention of nested parallelism and two documented layers |

## Criteria

- Identical scientific output and RNG streams across supported execution plans.
- Sequential execution requires no special infrastructure.
- Users, not package functions, choose local or remote execution backends.
- Full evidence workflows support caching, checkpointing, invalidation, retries,
  progress, and HPC schedulers.
- Scientific stage functions remain pure and independent of worker lifecycle.
- Only one orchestration layer parallelises a task at a time.
- Compute shortcuts have accurate claim labels and cannot produce confirmatory
  evidence accidentally.
- No Windows support is implied; ADR 0014 remains in force.

## Evidence

- The completed Stage 1 v2 run demonstrates that tens of thousands of tasks and
  durable progress/checkpoint state are realistic requirements.
- `future.apply` documents backend-independent parallel apply functions and
  reproducible RNG independent of worker count, chunking, or load balancing.
- The future package's developer guidance says package functions should not call
  `future::plan()`; the end user controls the backend.
- `targets` provides dependency-aware caching and invalidation. Its supported
  `crew` integration provides local workers, auto-scaling, retries, and HPC
  launchers through `crew.cluster`.

No benchmark yet selects bootstrap counts, chunk sizes, worker counts, or the
boundary at which distributed execution becomes faster. Those values remain
protocol-specific and must be measured before freezing.

## Decision

**Chosen:** define three compute tiers and use `future.apply` for reusable
package-level repetition, with `targets` + `crew` as the production/full-evidence
orchestration layer.

### Compute tiers

| Tier | Required computation | Permitted claim |
|---|---|---|
| `inspect` | Deterministic point estimates, descriptive atlas, and plots; no resampling | Exploratory, non-evidentiary |
| `standard` | Biological-unit resampling of association/interpretation models while holding the fitted state space fixed | Conditional uncertainty, explicitly labelled as conditional on the fitted decomposition |
| `evidence` | Biological-unit resampling that reruns every applicable fitted stage, association assessment, selection assessment, and Stage 2 estimation | Eligible for confirmatory evidence only after all other Stage 0 and protocol gates pass |

Tier names and semantics are fixed. Resample counts and stopping rules are not:
each evidence protocol predeclares them from accuracy/runtime benchmarks. All
artifacts record their tier. Tiers may change uncertainty depth and runtime but
must not change the point estimator, target hypothesis, or input cohort.

### 2026-07-15 amendment — design-preserving resampling

The biological resampling unit follows `SamplingDesign`; there is no generic row
bootstrap. Independent no-time analyses resample whole biological observations
and preserve discrete target-level counts for target uncertainty. Independent
time courses resample observations within target × observed-time design cells.
Repeated analyses resample whole subject trajectories within subject-invariant
target levels, retain every row/time for a sampled subject, and assign duplicate
draws new subject IDs. This policy applies both to fixed-decomposition
`standard` uncertainty and full-pipeline `evidence` stability. Resample counts
remain protocol-specific and empirically benchmarked.

### Execution boundary

- Reusable package functions may use `future.apply` for independent repeated
  work. They never call `future::plan()` or change `future.*` options. The
  default future plan remains sequential; users select `multisession`, cluster,
  or another compatible plan externally.
- Package functions use backend-independent seeded RNG and return results to the
  controlling process. Worker-side filesystem assumptions require an explicit
  shared-artifact contract; they are never implicit.
- Full Stage 0/evidence workflows use `targets` for the dependency graph and
  caching and `crew` for local or scheduler-backed workers. These are
  orchestration concerns, not stage contracts.
- Under `targets`/`crew`, individual tasks run their internal future work
  sequentially unless a protocol explicitly allocates nested resources. One
  layer parallelises by default.
- `future`/`future.apply` become Imports when the first package implementation
  uses them. `targets`, `crew`, `crew.cluster`, and scheduler adapters remain
  optional orchestration dependencies rather than core Imports.
- Existing `mclapply()` code is migrated when its execution seam is next changed;
  this ADR does not require an unrelated big-bang rewrite.

## Consequences

- Interactive users can choose sequential or multicore execution without a
  different scientific API.
- Full evidence runs gain a supported route to local and HPC orchestration.
- Conditional and full-pipeline uncertainty cannot be confused.
- The future Shiny interface can use package-owned asynchronous work without
  embedding worker policy in scientific functions.
- Tests must establish equality across sequential and a small multisession plan,
  including seeded stochastic results.
- Checkpoint/progress presentation remains derived from durable task state; no
  `progressr` dependency is introduced by this decision.
- Full-evidence protocol output remains evidentiary only when produced by the
  frozen protocol; choosing a faster backend does not change evidence status.

## Review trigger

Revisit if benchmarks show future serialization dominates realistic workloads,
if `targets`/`crew` cannot satisfy the remote cluster's security or filesystem
constraints, or if a single supported substrate can replace both layers without
coupling worker lifecycle to scientific contracts.
