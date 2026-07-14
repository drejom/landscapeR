# Stage 1 evidence publication plan

> **Historical implementation record.** Status and sequencing in this file
> describe its originating work and are superseded for current scheduling by
> the root [`ROADMAP.md`](../../ROADMAP.md).

**Scope:** publish the completed frozen `stage1-heterogeneous-v2` synthetic
artifact and document its confirmation outcome.  This implements #40 after the
remote run completed from source commit `6f1f061`.

## Fixed evidence facts

- All 40,960 tasks completed; no task failures.
- The artifact hash manifest and recorded source commit were verified.
- Calibration selected `C2_block_scaled_svd`.
- Its confirmation holdout failed (`thresholds_passed = FALSE`).
- Therefore no Stage 1 baseline is accepted; #24 stays blocked.

## Tasks

1. Retrieve the complete content-addressed artifact without changing it; verify
   its hashes and recorded provenance again in the publication checkout.
2. Add a render-only vignette that loads the committed artifact and reports the
   selection/holdout outcome. It must not recompute evidence or imply a
   biological or real-data claim.
3. Update ADR 0001 and the development log with the frozen negative result;
   explicitly forbid fallback to C1 or post-hoc tuning using the consumed
   holdout.
4. Test the vignette/package, run the full test suite and R CMD check, then
   perform an independent code review before committing.
