# K=1 Stage 0 revised acceptance protocol v4

## Purpose

Version 4 is a protocol-only refreeze of version 3. It changes no scientific
grid, generator setting, estimand, threshold, pass rule, outcome state,
resampling request, execution contract, workload, or claim boundary. It exists
because four version 3 acceptance tasks were exercised during runner
development before that runner passed review. Under RR-017 the complete version
3 seed set is retired, regardless of those outcomes.

Constructing, validating, testing, or reviewing this protocol must not derive a
version 4 seed, construct its acceptance manifest, execute an acceptance task,
or adapt the version 3 runner. Those are separate post-merge work.

## Frozen science

All scientific content is identical to
`docs/specs/k1-stage0-acceptance-protocol-v3.md`: 7,200 requested replicates
across the same destructive, repeated-subject, high-dimensional positive, and
null cells; absolute loading cosine at least 0.90 as the sole recovery gate;
typed downstream non-estimability; Wilson cell rules; strict completion and
evaluability; and the same out-of-domain and real-data stop boundaries.

## RNG authentication and separation

Version 4 embeds self-describing canonical RNG payloads for the exact disclosed
#189, #190, and #191 proof runs. Each payload records its task IDs, complete
L'Ecuyer-CMRG task states, named child seeds, derivation schemes, source-script
digest assertion, ordered serialization contract, and its own SHA-256 digest.
Task and child RNG identities are reproducibly authenticated from the contract;
source-script hashes are pinned historical assertions rather than independent
runtime identity. This
replaces the opaque historical manifest-digest references that version 3 could
not independently reconstruct.

The reviewed version 4 protocol merge SHA-1 will reveal the new indexed seed
block. Until that merge, no value exists. The complete revealed version 3
scalar block from 664979464 through 665037063, its canonical task identities,
and its derived streams are reserved, together with all calibration and
historical acceptance streams. The later v4 manifest validator must reject any
collision before any task can execute.

## Separation of work

This change freezes only the protocol. A later reviewed change may adapt the
existing backend-independent targets runner to version 4 and reveal the v4
manifest. Only after that runner revision merges may the independent HPC run
begin. Integration tests use labelled fixture streams and may never use a v4
acceptance row.

## Provenance

- Source issue: #193
- Scientific source: immutable version 3 protocol
- Incident rule: RR-017
- Acceptance results inspected while refreezing science: no
- Claim: predeclared acceptance protocol only
