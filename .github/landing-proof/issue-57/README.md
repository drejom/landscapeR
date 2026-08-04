# Issue 57 execution and reproducibility proof

## Compute-tier contract

| Tier | Repetition depth | Claim boundary |
|---|---|---|
| `inspect` | none | exploratory, non-evidentiary |
| `standard` | biological-unit resampling with frozen state space | conditional uncertainty |
| `evidence` | every applicable fitted stage rerun | eligible only after separate evidence gates |

## Representative typed result

```text
class: landscapeR_repetition_result
compute_tier: standard
run_seed: 4103
rng_kind: L'Ecuyer-CMRG
seed_derivation: sha256-lecuyer-state-v1
task_ids: independent:PC1:unadjusted:bootstrap:0001 ... 0003
account: requested=3, completed=3, failed=0
denominator: all-requested-tasks
```

The repeated-subject adapter reports the same fields with stable
`repeated:*` identities while retaining complete-subject draw
construction. A partial-result test records known non-estimability and an
unexpected task error as stable failures without removing either task from the
denominator.

## Backend comparison

`tests/testthat/test-future-repetition.R` compares the complete typed result,
including its digest, under sequential, two-worker multisession, explicit
chunking values, and nested sequential-execution modes. Local restricted
sandboxes may skip socket-backed assertions; CI treats a missing multisession
backend as a failure.

No worker count, chunk size, or resample count is frozen by this change. The
small comparison establishes invariance, not a performance default; realistic
serialization and scheduling benchmarks remain required before any default is
proposed. This is execution and reproducibility proof, not scientific
acceptance evidence.
