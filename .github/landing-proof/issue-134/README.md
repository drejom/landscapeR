# Issue #134 landing proof: remote future workers

## Claim boundary

This is operational execution proof only. It does not select an HPC scheduler,
queue, project, worker count, chunk size, or scientific acceptance threshold.
The cluster proof used two local PSOCK workers because they exercise the same
`future::cluster` contract documented for user-allocated remote hosts.

## Cold-reader conclusion

landscapeR can now reject inconsistent remote worker environments before a
scientific workload, measure realistic assay-transfer costs, and reproduce its
seeded repetition evidence through a cluster-compatible future backend. The
measurements strongly disfavor one-future-per-observation for this payload and
therefore support retaining user-owned scheduling rather than freezing a
package default.

## Worker preflight

The installed package was run under `future::cluster` with two PSOCK workers.
Both distinct processes reported the declared `issue-134-proof` revision, R
4.5.2, and exact controller versions of landscapeR, future, future.apply, and
digest.

| Requested workers | Distinct workers | Matching revision | Matching R | Matching dependencies | Preflight result |
|---:|---:|---|---|---|---|
| 2 | 2 | yes | yes | yes | pass |

Negative tests show that revision mismatch and incomplete worker coverage raise
`landscapeR_worker_preflight_error` with per-probe diagnostic rows.

## Serialization and chunk collection

The representative assay contained 1,200 features by 200 observations. Its
serialized payload and reconstructed collection were each 960,070 bytes.
Times are medians of three repetitions on the development Mac and are not a
performance guarantee.

| Observations per chunk | Submitted chunks | Sequential (s) | Two-worker cluster (s) | Reconstructed digest identical |
|---:|---:|---:|---:|---|
| 1 | 200 | 0.572 | 8.041 | yes |
| 8 | 25 | 0.118 | 0.870 | yes |
| 32 | 7 | 0.074 | 0.248 | yes |
| 200 | 1 | 0.063 | 0.065 | yes |

The seeded repetition result was byte-identical across sequential and cluster
plans, including execution digest
`60461d0921c567b67cc8acb3e52aa3ff819ac7f3805d36d2d11d0220d749bec5`.

## Gadi environment observation

A read-only login-node inspection on 2026-08-04 confirmed `qsub` and the
versioned `R/4.5.0` module. That module starts R 4.5.0 but does not itself
provide future, future.apply, digest, batchtools, or future.batchtools. The
deployment guide therefore requires a shared user-managed library and exact
revision/dependency preflight; it does not imply that an unconfigured Gadi
module is ready to run landscapeR.

## Reproduction

Install the branch into a clean library, set `LANDSCAPER_REVISION`, then run
[`reproduce.R`](reproduce.R). The script selects sequential and two-worker
cluster plans externally, invokes the package preflight and benchmark, and
asserts identical scientific execution and payload digests.
