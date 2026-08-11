# K=1 Stage 0 acceptance protocol v2

## Problem statement

Protocol v1 began its generic positive grid at 24 observations and evaluated
the matching negative controls only from 48 observations. That design could
not locate the lower boundary at which recovery fails, even though experiments
with two or three biological replicates per group and time point are common.
It also did not test the shared-baseline design in which controls are observed
only at the first time while treated samples are observed throughout a time
course. Finally, expanding the grid exposed seed collisions in v1's independent
hash-to-integer mapping before any production seeds were derived.

## Decision

`K1AcceptanceProtocol` version 2 is the current protocol for new acceptance
runs. Version 1 remains valid historical evidence and its constructor,
validator, manifests, summaries, and artifacts remain readable. Evidence from
the two versions must retain its own protocol identifier, digest, execution
contract, and seed manifest.

Version 2 changes only the operating-range and safety questions described
below. Existing estimators, thresholds, replicate counts, failure denominators,
and AML synchronized-trajectory gates remain frozen.

## Grids and controls

The generic double-well positive control and both negative-control families use
the complete Cartesian grid:

- `n = 8, 12, 16, 24, 48, 96, 132, 192`
- `p = 100, 1,000, 10,000, 20,000`

Every declared `n` is eligible to become the supported minimum. A value is
supported only when the generic positive control, pure-noise control, and
single-well control pass at every declared feature count. Failed executions
remain in the requested denominator.

The synchronized AML control retains its version 1 grid and gates.

Version 2 adds one design-safety control with:

- two conditions, `control` and `treated`;
- four observed times;
- three independent biological units in every observed condition-time cell;
- controls observed only at the first time;
- treated samples observed at all four times; and
- 1,000 features.

Each of the three controls appears exactly once. No control is duplicated into
later cells. The required result is a typed `non-identifiable-design`
abstention that reports three missing later control-time cells, three unique
control observations, and 15 total observations. This control tests safe
failure. It does not authorize a shared-baseline trajectory estimator.

## Replicates, thresholds, and evidence

- Each generic positive cell receives 100 replicates.
- Each cell in each negative-control family receives 200 replicates.
- Each synchronized AML cell receives 100 replicates.
- The shared-baseline safety control receives 100 replicates.
- All version 1 scientific thresholds, resample counts, permutation counts,
  and normalized execution settings remain unchanged.
- Every requested replicate, including failures, remains in cell denominators.
- The flattened audit table records the shared-baseline abstention reason,
  missing control-time cells, unique controls, and total observations.
- Summaries and plots identify their protocol version. Version 1 artifacts do
  not acquire version 2 panels or claims when read by current code.

The full version 2 manifest contains 17,000 independently requested tasks:
3,200 generic positive, 6,400 pure noise, 6,400 single well, 900 synchronized
AML, and 100 shared-baseline safety replicates.

## Deterministic seed contract

Production seeds remain unknowable until the reviewed version 2 merge commit
exists. They must not be derived or executed in the implementation pull
request. Development tests and resource pilots use explicitly labelled,
non-production seeds.

Version 2 uses `sha256-merge-commit-indexed-block-v2`:

1. Bind the protocol identifier, protocol digest, and reviewed merge commit to
   one merge-specific seed-block start.
2. Order tasks canonically by the frozen seed-plan control order, each
   control's declared grid order, and ascending replicate index.
3. Assign each task a four-integer block by its one-based task ordinal.
4. Start roots at or above 100,000, above all disclosed calibration streams,
   and keep every stream at or below 2,147,483,644.

The fixed block stride guarantees that all 17,000 task streams are disjoint.
Any reserved-stream overlap, duplicate task identity, changed ordering, or
digest mismatch is a protocol failure. Version 1 retains its original
`sha256-merge-commit-cell-v1` contract.

## Public and contributor contract

- `k1_acceptance_protocol()` returns version 2 by default.
- `k1_acceptance_protocol("1")` returns the exact historical version 1
  protocol.
- The public validators reconstruct and validate the version named by each
  protocol or manifest rather than silently upgrading it.
- Artifact verification binds the protocol, manifest, results, summaries, and
  runtime identity. Mixed or relabelled evidence is rejected.
- The legacy `phase_a_merge_commit` argument name denotes the reviewed merge
  commit that froze the supplied protocol. For version 2 it must be the
  reviewed version 2 merge, not the historical version 1 merge.

## Verification before production

The implementation pull request must show:

- version 1 round-trip preservation;
- version 2 construction, validation, deterministic task expansion, and exact
  task counts;
- collision-free development manifests without disclosing production roots;
- the shared-baseline safety control returning the required typed abstention;
- version-aware summaries, captions, and plots; and
- a refreshed Gemini `hprcc` development-only workload and resource estimate
  for the expanded task mix.

Production execution begins only after review, merge, installation of the exact
merged revision on Gemini, and a successful preflight. Acceptance outcomes may
not tune this protocol.

## Provenance

- Source issue: #177
- Supersedes for new runs: `k1-stage0-acceptance-protocol-v1.md`
- Acceptance results inspected while defining version 2: no
- Claim status before production execution: predeclared acceptance protocol

## Out of scope

- Treating shared baseline controls as repeated or independent observations at
  unobserved later times.
- Selecting a simpler trajectory model after seeing the safety-control result.
- Changing frozen scientific thresholds in response to lower-tail outcomes.
- Asynchronous disease-onset validation beyond the existing synchronized AML
  control.
- Deriving sample-size recommendations before the complete version 2 artifact
  has passed verification.
