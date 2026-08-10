# Gemini hprcc deployment

This guide owns the City of Hope Gemini execution profile for durable
landscapeR acceptance workloads. The scientific protocol and task graph remain
package-owned. Slurm resources, worker scale, the targets store, and monitoring
remain caller-owned operational policy supplied through `hprcc`.

## Verified environment

The following facts were verified on Gemini on 2026-08-09:

| Check | Verified value |
|---|---|
| Login path | `ssh -J studio gemini` |
| Scheduler partition | `compute` |
| Singularity | `/packages/easy-build/software/singularity/3.7.0/bin/singularity` |
| rbiocverse image | `/packages/singularity/shared_cache/rbioc/rbiocverse_3.22.sif` |
| Shared R library | `/packages/singularity/shared_cache/rbioc/rlibs/bioc-3.22` |
| R and Bioconductor | R 4.5.2, Bioconductor 3.22 |
| Orchestration | targets 1.12.0, crew 1.3.1, crew.cluster 0.4.0, hprcc 0.2.3 |

An hprcc Slurm smoke job completed on a Gemini compute node and independently
reported the installed landscapeR revision. The smoke log also reproduced the
known R stack-imbalance warning tracked separately; it did not affect the job's
successful exit or revision check.

## Install one reviewed revision

Install a source archive stamped with `Config/landscapeR/Revision` into the
shared Bioconductor 3.22 library. The controller and every worker must report
that same full revision. Do not run a scientific graph from a mutable checkout
or overwrite the shared installation with an unreviewed branch.

The current phase-A protocol revision is installed only to verify the platform.
Install the reviewed runner merge before its production graph is started.

## Dedicated execution directory

Use one run directory under Gemini scratch:

```sh
RUN_ROOT="/scratch/$USER/landscapeR/k1-independent-acceptance"
mkdir -p "$RUN_ROOT"
cd "$RUN_ROOT"
cp "$(Rscript -e 'cat(system.file("extdata", "k1-acceptance-gemini-targets.R", package = "landscapeR"))')" _targets.R
```

The profile sets `HPRCC_TARGETS_STORE_BASE` before attaching hprcc. This is
essential because a user-level targets configuration may otherwise point
workers at an unrelated project's store. The profile also enables persistent
hprcc job scripts and autometric worker logs under the run's `_targets`
directory.

## Custom controller and native metrics

The supplied profile adds a dedicated `k1-acceptance` controller with
`hprcc::add_controller()`. Its initial resource request is deliberately
conservative. Before the independent run, execute the largest generic and
negative cells with development-only seeds, then inspect hprcc's native
autometric evidence:

```r
logs <- hprcc::read_targets_logs(
    file.path(Sys.getenv("HPRCC_TARGETS_STORE_BASE"), "logs")
)
hprcc::summarize_resource_usage(
    path = file.path(Sys.getenv("HPRCC_TARGETS_STORE_BASE"), "logs"),
    targets_file = "_targets.R"
)
```

Set the custom controller's CPUs, memory, wall time, and tasks per worker from
those measurements with a documented safety margin. Do not change scientific
grid values, repetition counts, normalized estimator settings, or thresholds
in response to the pilot.

## Production launch

Only after the runner revision is reviewed, merged, installed, and preflighted:

```sh
export LANDSCAPER_K1_PHASE_A_MERGE=<reviewed-phase-A-merge-SHA-1>
Rscript -e 'targets::tar_make(use_crew = TRUE)'
```

The first production make reveals the deterministic post-merge seed manifest.
Do not run this command during runner development. If an operational branch
fails, fix the environment and repeat `tar_make()` from the same run directory;
targets resumes valid branches. Artifact publication and verification remain
blocked until every requested branch has returned.

Monitor with `targets::tar_progress()`, Slurm accounting, and hprcc's log
readers. A green scheduler state is insufficient on its own. The final
content-addressed artifact must pass
`landscapeR::verify_k1_acceptance_artifact()` before any acceptance claim is
made.

## Boundaries

- Never derive or execute the production seed manifest during runner review.
- Never use calibration output to change frozen acceptance thresholds.
- Never place credentials, SSH configuration, or private host material in the
  package.
- Keep scratch stores and worker logs outside Git. Only reviewed,
  content-addressed evidence belongs under the package's governed benchmark
  location.
- Resource changes are operational. Scientific graph changes require a new
  reviewed protocol contract.
