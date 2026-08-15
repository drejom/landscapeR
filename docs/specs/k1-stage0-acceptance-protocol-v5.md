# K=1 Stage 0 revised acceptance protocol v5

## Purpose

Version 5 is a protocol-only refreeze of version 4. It changes no scientific
grid, generator setting, estimand, threshold, pass rule, outcome state,
resampling request, execution contract, workload, or claim boundary. It exists
because version 4 acceptance tasks were executed before the revision-stamped
runner passed review and merged. Under RR-017 the complete version 4 seed set
is retired, regardless of those outcomes.

Constructing, validating, testing, or reviewing this protocol must not derive a
version 5 seed, construct its acceptance manifest, execute an acceptance task,
or adapt the version 4 runner. Those are separate post-merge work.

## Frozen science

All scientific content is identical to
`docs/specs/k1-stage0-acceptance-protocol-v4.md`: 7,200 requested replicates
across the same destructive, repeated-subject, high-dimensional positive, and
null cells; absolute loading cosine at least 0.90 as the sole recovery gate;
typed downstream non-estimability; Wilson cell rules; strict completion and
evaluability; and the same out-of-domain and real-data stop boundaries.

## RNG authentication and separation

Version 5 retains version 4's self-describing canonical RNG payloads for the
exact disclosed #189, #190, and #191 calibration proof runs. The reviewed
version 5 protocol merge SHA-1 will reveal a new indexed seed block. Until that
merge, no value exists.

The complete revealed version 3 scalar block from 664979464 through 665037063
and version 4 scalar block from 990320213 through 990377812 are reserved with
their canonical task identities and derived streams, together with all
calibration and historical acceptance streams. The later version 5 manifest
validator must reject any collision before any task can execute.

## Separation of work

This change freezes only the protocol. A later reviewed change may adapt the
backend-independent targets runner to version 5 and reveal its manifest. Only
after that runner revision merges may the independent HPC run begin.
Integration tests use labelled fixture streams and may never use a version 5
acceptance row.

## Provenance

- Source issue: #193
- Scientific source: immutable version 4 protocol
- Incident rule: RR-017
- Acceptance results inspected while refreezing science: no
- Claim: predeclared acceptance protocol only
