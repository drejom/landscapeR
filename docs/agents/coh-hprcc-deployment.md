# City of Hope hprcc deployment

This guide owns current landscapeR execution on the Apollo and Gemini
clusters. The scientific protocol and target graph remain package-owned.
`hprcc` owns cluster detection, partitions, worker libraries, bind mounts,
container execution, and named Slurm resource controllers.

Historical Gemini-only execution evidence remains in
[`gemini-hprcc-deployment.md`](gemini-hprcc-deployment.md). Do not copy its
retired cluster-specific profiles into a new run.

## Verified environment

The active profile requires R 4.5.2, Bioconductor 3.22, `targets 1.12.0`,
`crew 1.3.2` or a compatible release, `crew.cluster 0.4.0`, and `hprcc 0.2.3`.
Install one reviewed landscapeR revision in the shared Bioconductor 3.22
library. The controller and every worker must report that same full revision.
The installed hprcc must expose `slurm_workers` through its internal
`create_controller()` implementation until
[hprcc issue 36](https://github.com/cohmathonc/hprcc/issues/36) is resolved.

On 2026-08-14, a configuration-free smoke graph completed on Apollo. Slurm
dispatched hprcc's default `small` worker, and controller and worker reported
the same landscapeR revision. This is operational evidence only. It did not
load an acceptance protocol, derive governed seeds, or publish a scientific
artifact.

## Prepare a run directory

Start a standard rbiocverse session that is already running as a Slurm job.
Use a dedicated cluster-visible directory and copy the active profile from the
installed package:

```sh
mkdir -p /path/to/shared/landscapeR/k1-revised-acceptance
cd /path/to/shared/landscapeR/k1-revised-acceptance
cp "$(Rscript -e 'cat(system.file("extdata", "k1-revised-acceptance-targets.R", package = "landscapeR"))')" _targets.R
```

The current working directory owns the targets store and artifact directory.
Do not reuse a store from another protocol or execution attempt.

## Temporary hprcc container workaround

[hprcc issue 35](https://github.com/cohmathonc/hprcc/issues/35) tracks a stale
fallback image name. A standard rbiocverse session already exports its active
image through `SINGULARITY_CONTAINER`. The profile validates that this is a
versioned `rbiocverse` image and temporarily passes the observed value back to
hprcc. It does not construct an Apollo or Gemini path.

Remove this override after hprcc's cluster defaults select current rbiocverse
images on both clusters.

## Temporary bounded-worker workaround

[hprcc issue 36](https://github.com/cohmathonc/hprcc/issues/36) tracks the
missing `slurm_workers` argument in exported `add_controller()`. The active
profile temporarily uses hprcc's own controller constructor to request the
development-pilot resource class, 96 concurrent workers, and at most 100
complete tasks per worker. hprcc continues to own cluster detection,
partitions, libraries, bind mounts, the container, and Slurm submission.

The profile serializes only scheduler submission calls when the active
environment relays them over SSH. Queued workers still execute concurrently,
so this avoids relay exhaustion without underusing cluster compute. It changes
only scheduler concurrency and process reuse. The larger per-worker task cap
prevents short branches from requiring repeated scheduler submissions. Task
identities, RNG streams, scientific inputs, thresholds, and results are
unchanged. Remove the internal constructor call when hprcc's public API
forwards the worker limit.

## Launch revised acceptance

Only after the protocol and runner revisions are reviewed, merged, and
installed, copy the installed cluster-neutral profile into a dedicated shared
run directory as `_targets.R`, and copy
`k1-revised-acceptance-launch.sh` beside it. Supply the reviewed upstream
rbiocverse `container/scripts/cluster-config.sh`, both reviewed revisions, and
the run directory through the declared environment variables. Invoke the
tracked launcher rather than reconstructing the controller command ad hoc:

```bash
RBIOCVERSE_CONFIG=/path/to/rbiocverse/container/scripts/cluster-config.sh \
LANDSCAPER_K1_PROTOCOL_MERGE=<reviewed-protocol-merge-SHA-1> \
LANDSCAPER_K1_RUNNER_MERGE=<reviewed-runner-merge-SHA-1> \
LANDSCAPER_RUN_ROOT=/path/to/shared/run \
bash /path/to/k1-revised-acceptance-launch.sh
```

The launcher submits `tar_make()` as a Slurm job and enters the rbiocverse
container there; it never runs the controller on a login node. The active
profile declares only the measured workload size and bounded concurrency. The
installed `hprcc` configuration owns worker infrastructure and submission.

## Monitor and verify

Monitor target progress, Slurm accounting, and hprcc's persistent logs:

```r
targets::tar_progress()
hprcc::summarize_resource_usage(
    path = file.path(getwd(), "_targets", "logs"),
    targets_file = "_targets.R"
)
```

A completed Slurm job is not scientific acceptance. Every requested branch
must return, artifact publication must complete, and the final artifact must
pass `landscapeR::verify_k1_revised_acceptance_artifact()` before any claim is
made. If an operational branch fails, repair the environment and rerun
`tar_make()` from the same directory so targets can retain valid branches.

## Boundaries

- Never derive or execute production seeds during protocol review.
- Never change scientific thresholds in response to scheduler behavior.
- Never place credentials, SSH configuration, or private host material in the
  package.
- Cluster-specific paths and partitions belong to rbiocverse and hprcc, not
  landscapeR.
- Resource-class selection is operational policy informed by native hprcc
  telemetry. Scientific graph changes require a reviewed protocol revision.
