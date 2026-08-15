# K=1 Stage 0 revised acceptance protocol v5

## Purpose

Version 5 is a refreeze of version 4 plus the reviewed runner binding. It
changes no scientific grid, generator setting, estimand, threshold, pass rule,
outcome state, resampling request, execution contract, workload, or claim
boundary. It exists because version 4 acceptance tasks were executed before
the revision-stamped runner passed review and merged. Under RR-017 the complete
version 4 seed set is retired, regardless of those outcomes.

The reviewed runner derives the version 5 manifest only from the merged
protocol revision and requires an independently observed matching runner
revision on every worker. No version 5 acceptance task has executed in this
change; execution remains downstream of this runner revision and its governed
preflight.

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
version 5 protocol merge is
`f668e1e0f49f66b8bd8c244ca6fb667a9b39d896`; it reveals the new indexed seed
block through the manifest, while the runner revision remains a separate
provenance field.

The complete revealed version 3 scalar block from 664979464 through 665037063
and version 4 scalar block from 990320213 through 990377812 are reserved with
their canonical task identities and derived streams, together with all
calibration and historical acceptance streams. The later version 5 manifest
validator must reject any collision before any task can execute.

The labelled repeated-subject validator fixture reserves scalar seeds 4242
through 4249. This block lies below the acceptance minimum and cannot enter
version 5 evidence; future manifest validation must retain that separation.

## Separation of work

This change adapts the backend-independent targets runner to version 5 and
reveals its manifest. Only after this runner revision merges may the
independent HPC run begin.
Integration tests use labelled fixture streams and may never use a version 5
acceptance row.

## Provenance

- Source issue: #193
- Scientific source: immutable version 4 protocol
- Incident rule: RR-017
- Version 4 result structure inspected while diagnosing collection: yes
- Scientific settings changed in response to acceptance outcomes: no
- Claim: predeclared acceptance protocol and reviewed runner only; no scientific
  acceptance result
