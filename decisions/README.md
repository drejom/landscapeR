# Architecture Decision Records

Every non-trivial algorithm or design choice gets a record here before code is written.
The format is deliberately lightweight — the goal is a defensible paper trail, not ceremony.

## When to write one

- Choosing a concrete algorithm implementation for a stage contract
- Picking a dependency (package, external tool, reticulate bridge)
- Changing a stage contract or container schema in a breaking way
- Any time you're tempted to write "we picked X because it was available"

## File naming

```
NNNN-<stage>-<decision-slug>.md
```

Examples:
```
0001-stage1-hogsvd-implementation.md
0002-stage2-dynamics-estimator.md
0003-container-schema-v1-freeze.md
```

## Template

See `0000-template.md`.

## Status vocabulary

- **proposed** — written, not yet acted on
- **accepted** — decision made, implementation may or may not exist yet
- **superseded-by NNNN** — replaced; link to the new ADR
- **rejected** — considered and ruled out; keep for the record
