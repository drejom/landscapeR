# Gadi future-worker deployment

This guide configures landscapeR inside a user-owned PBS allocation on NCI
Gadi. Package code does not choose the queue, project, resources, worker count,
future plan, or credentials.

## Verified platform boundary

The following login-node facts were observed on 2026-08-04 and should be
rechecked before a production run:

| Check | Observed state |
|---|---|
| Scheduler client | `qsub` available from the PBS module |
| R module | `R/4.5.0` available and starts R 4.5.0 |
| Unconfigured R module | `future`, `future.apply`, `digest`, `batchtools`, and `future.batchtools` absent |

The absence is evidence for the environment contract: a plain module load is
not a valid landscapeR worker. Install one revision and its locked dependencies
into a shared project library visible from every requested node. NCI recommends
versioned modules and PBS scripts with explicit project, CPU, memory, walltime,
working-directory, and storage requests.

## Prepare one shared revision

```sh
module load R/4.5.0
export LANDSCAPER_SOURCE=/path/to/landscapeR
export LANDSCAPER_R_LIB=/path/to/shared/project/R-library
export R_LIBS_USER="$LANDSCAPER_R_LIB"
export LANDSCAPER_REVISION="$(git -C "$LANDSCAPER_SOURCE" rev-parse HEAD)"
mkdir -p "$LANDSCAPER_R_LIB"
```

First install dependencies into that library with the project's chosen lockfile
or package-management procedure. Then create a disposable build copy, stamp its
Git identity into installation metadata, and install it. The stamp comes from
the checked-out source rather than from a claim propagated to workers:

```sh
BUILD_SOURCE="$PBS_JOBFS/landscapeR-build"
cp -R "$LANDSCAPER_SOURCE" "$BUILD_SOURCE"
printf '\nConfig/landscapeR/Revision: %s\n' "$LANDSCAPER_REVISION" >> "$BUILD_SOURCE/DESCRIPTION"
R CMD INSTALL --library="$LANDSCAPER_R_LIB" "$BUILD_SOURCE"
```

The controller and every worker must use the same `R_LIBS_USER`, R module, and
package versions. `LANDSCAPER_REVISION` is the controller's expected identity;
workers independently read the installed artifact metadata.

## User-owned PBS allocation and future plan

Copy and edit this template outside the package. Resource values are
placeholders, not landscapeR defaults:

```sh
#!/bin/bash
#PBS -P <project>
#PBS -q <queue>
#PBS -l ncpus=<ncpus>
#PBS -l mem=<memory>
#PBS -l walltime=<hh:mm:ss>
#PBS -l storage=<required-filesystems>
#PBS -l wd

module load R/4.5.0
export R_LIBS_USER=/path/to/shared/project/R-library
export LANDSCAPER_REVISION=<exact-commit-sha>
Rscript /path/to/user-owned-analysis.R
```

In `user-owned-analysis.R`, the user selects a cluster plan from hosts allocated
by PBS, runs the mandatory preflight, then starts scientific work:

```r
hosts <- scan(Sys.getenv("PBS_NODEFILE"), what = character(), quiet = TRUE)
stopifnot(length(hosts) > 0L)

revision <- Sys.getenv("LANDSCAPER_REVISION")
worker_library <- Sys.getenv("R_LIBS_USER")
stopifnot(nzchar(revision), nzchar(worker_library))

future::plan(
    future::cluster,
    workers = hosts,
    rscript_libs = worker_library
)
on.exit(future::plan(future::sequential), add = TRUE)

preflight <- landscapeR::preflight_future_workers(
    expected_revision = revision,
    workers = length(hosts)
)

transfer <- landscapeR::benchmark_future_assay(
    representative_assay,
    chunk_sizes = c(1L, 8L, 32L),
    repetitions = 3L
)

# Only after preflight succeeds:
result <- landscapeR::associate_metadata(
    data,
    specification,
    compute_tier = "standard"
)
```

`future::cluster` accepts host names and creates PSOCK workers; future's own
documentation leaves backend selection to the user. A direct PBS scheduler
backend such as `future.batchtools::batchtools_torque` is optional user
configuration. Durable workflow scheduling is owned by issue #135.

## Failure and security boundary

- Do not proceed after a preflight error. Inspect `condition$diagnostics` for
  launch, coverage, revision, R, missing-package, or package-version failures.
- Do not place tokens, SSH keys, project credentials, personal host names, or
  private library paths in package configuration or Git.
- Do not write scientific artifacts to worker-local storage unless the
  analysis explicitly defines collection and retention.
- Do not infer an efficient chunk size from the example. Benchmark the actual
  assay and record the measured environment.

Primary references: NCI, “Job Submission Tutorial” (2025); Futureverse,
`future::plan()` and `future::cluster` documentation (accessed 2026-08-04);
Futureverse, `future.batchtools` documentation (accessed 2026-08-04).
