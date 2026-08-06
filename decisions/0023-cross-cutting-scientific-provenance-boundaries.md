# 0023 — Scientific provenance boundaries and RNG replay identity

**Stage:** cross-cutting
**Status:** accepted
**Date:** 2026-08-04

## Context

Every scientific stage appends a `ProvenanceStep`, but the former recorder
default hashed the entire incoming `StateTransitionData`. That value includes
its growing provenance history, so two equivalent scientific inputs could have
different hashes. The same record copied the ambient `.Random.seed`, which is
session state rather than a declared or sufficient replay contract.

The package needs provenance that identifies the scientific inputs actually
consumed and, for stochastic work, the stable seed or stream identity chosen by
the caller. The recorder cannot infer either boundary from an arbitrary
container.

## Options considered

| Option | Source / reference | Key property | Disqualifier or concern |
|---|---|---|---|
| Hash the whole container and capture `.Random.seed` | Previous implementation | Automatic at the recorder | Hash includes unrelated audit history; ambient RNG state has no declared scientific meaning |
| Strip known incidental fields inside the recorder | Internal helper | Preserves an automatic default | The recorder still guesses which data, metadata, or prior stage is scientifically relevant |
| Require caller-scoped hashes and a declared RNG identity | Issue #127 architecture audit | Makes the consuming method state its exact input and replay boundary | Adds a small explicit obligation for method authors |

## Criteria

- Equivalent scientific inputs have stable hashes despite unrelated audit
  history.
- A provenance reader can identify the seed and stream used without recreating
  the original interactive session.
- Invalid or incomplete replay claims fail at the public boundary.
- Existing serialized objects retain their legacy slot layout.
- New method authors face one documented, testable contract.

## Evidence

The architecture audit documented that every production caller already
overrode the whole-container hash default, making that default both unused and
scientifically inconsistent. Review of the first implementation also showed
that merely adding an `rng` argument was insufficient: no production caller
used it, and an arbitrary named list could be recorded as if it supported
replay. Focused tests now cover real stochastic generators and malformed replay
identities. No new estimator or scientific threshold is evaluated by this ADR.

## Decision

**Chosen:** each scientific caller must supply named hashes for the inputs it
actually consumes. Stochastic callers must additionally supply a validated RNG
identity containing `run_seed`, `rng_kind`, `seed_derivation`, and `task_id`;
multi-stream operations also provide uniquely named integer `streams`.

Input names are unique and values are lowercase hexadecimal MD5, SHA-1,
SHA-256, or SHA-512 digests. The dedicated `rng` argument is the only route to
the canonical `params$rng` record; callers cannot bypass validation by placing
that field inside general parameters.

`record_provenance()` validates and stores this identity under `params$rng`.
It does not inspect or store ambient `.Random.seed`. The legacy
`ProvenanceStep@rng_seed` slot remains readable for schema compatibility but is
empty in newly constructed records. Deterministic callers omit `rng` rather
than inventing a seed.

## Implementation landing proof

- **Proof classification:** required
- **Before/after or representative output:** the issue #127 workflow and
  invalid-case table show caller-owned input and RNG boundaries.
- **Current documentation affected:**
  `docs/architecture/core-construction-and-provenance.md`.
- **Claim status:** architecture and reproducibility implementation proof; no
  scientific method or threshold is accepted.
- **Exemption category and rationale:** not applicable.

## Consequences

- Provenance hashes remain stable when unrelated upstream audit history changes.
- Replay claims are explicit, inspectable, and rejected when required identity
  fields are missing.
- Method authors must decide and name their scientific input boundary.
- The compatibility slot remains part of the current schema even though new
  records do not populate it.
- Seed derivation semantics remain owned by the caller or the shared
  future-repetition substrate and must be identified, not reimplemented in the
  recorder.

## Review trigger

Revisit this decision if a future schema migration can replace the compatibility
slot with a typed RNG identity, or if a stochastic backend cannot be reproduced
from the declared seed, derivation scheme, task identity, and named streams.
