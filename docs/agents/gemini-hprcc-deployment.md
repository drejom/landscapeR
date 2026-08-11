# Gemini hprcc deployment

This guide owns the City of Hope Gemini execution profile for durable
landscapeR acceptance workloads. The scientific protocol and task graph remain
package-owned. Slurm resources, active worker concurrency, the targets store,
and monitoring remain operational policy supplied through `hprcc` and Slurm.
The package profile fixes only the resources and number of complete tasks
handled by each worker.

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

Development snapshots are installed only in isolated scratch libraries to
verify the platform and size workers. Install the reviewed protocol v2 merge
before its production graph is started.

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
`hprcc::add_controller()`. Its measured resource request follows the completed
development pilot below. If the runner, container, scheduler, or largest-cell
workload changes materially, repeat that pilot with development-only seeds and
inspect hprcc's native autometric evidence:

```r
logs <- hprcc::read_targets_logs(
    file.path(Sys.getenv("HPRCC_TARGETS_STORE_BASE"), "logs")
)
hprcc::summarize_resource_usage(
    path = file.path(Sys.getenv("HPRCC_TARGETS_STORE_BASE"), "logs"),
    targets_file = "_targets.R"
)
```

Update the custom controller's CPUs, memory, wall time, and tasks per worker
only from those measurements with a documented safety margin. Do not change
scientific grid values, repetition counts, normalized estimator settings, or
thresholds in response to the pilot.

### Development pilot evidence

On 2026-08-10, revision-stamped development snapshot
`d98824c8795a55ffdfc08703322e47b31db4156bd` ran five representative protocol
v2 tasks: generic recovery at `n = 8` and `n = 192` with `p = 20,000`, both
negative controls at `n = 192` and `p = 20,000`, and the 15-observation,
1,000-feature shared-baseline safety control. The stamped source bundle SHA-256
was `1c9250c58562e651205d00ba81842ec647e6c3f7d37fe06c0cc42bca78baaa79`.
Every task used a fixed disclosed development root outside the governed
manifest, and all five completed successfully. Three tasks emitted expected
BBP signal-strength diagnostics. No scheduler or numerical failure occurred.
The scientific values are not acceptance evidence and are not retained by the
package.

hprcc's native resource summary reported:

| Measurement | Observed value |
|---|---:|
| Peak memory | 1.57 GB |
| Peak CPU | 5.3% |
| Duration | 5.5 minutes |
| hprcc recommendation | `tiny` |

The package profile therefore requests 2 CPUs, 8 GB, and 60 minutes for one
complete replicate per worker. This retains more than five times the observed
peak memory and more than ten times the observed duration while following
hprcc's named recommendation. Protocol v2 phase B1 contains 16,100 scheduler
branches: 3,200 generic, 6,400 pure-noise, 6,400 single-well, and 100
shared-baseline safety tasks. This is 91.7% more branches than protocol v1 phase
B1, so production planning must provide adequate concurrency and scheduler
throughput; it does not require a larger per-worker resource class. Native
resource logs remain operational evidence outside the scientific artifact
digest.

## Production launch

Only after the runner revision is reviewed, merged, installed, and preflighted:

```sh
export LANDSCAPER_K1_PROTOCOL_MERGE=<reviewed-protocol-v2-merge-SHA-1>
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

- Never derive or execute the production seed manifest during protocol review.
- Never use calibration output to change frozen acceptance thresholds.
- Never place credentials, SSH configuration, or private host material in the
  package.
- Keep scratch stores and worker logs outside Git. Only reviewed,
  content-addressed evidence belongs under the package's governed benchmark
  location.
- Resource changes are operational. Scientific graph changes require a new
  reviewed protocol contract.
