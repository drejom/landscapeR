# Domain Docs

Multi-context repo. `CONTEXT-MAP.md` at the root points at per-context files under `context/`.

## Before exploring, read these

- **`CONTEXT-MAP.md`** at the repo root — lists the four contexts and their files.
- The relevant `context/<name>.md` for the area you're working in.
- **`decisions/`** — shared ADRs covering algorithm choices across all stages. Read ADRs that touch the area you're about to work in.

If any of these files don't exist, proceed silently. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill creates them lazily when terms or decisions actually get resolved.

## Contexts

| Context | File | Covers |
| ------- | ---- | ------- |
| shared  | `context/shared.md`  | Container (`StateTransitionData`), registry, provenance, boundary validation, RNG |
| stage0  | `context/stage0.md`  | Synthetic control ladder, ground truth generation, recovery benchmarks |
| stage1  | `context/stage1.md`  | Comparative decomposition — GSVD / HO-GSVD, subspace vocabulary |
| stage2  | `context/stage2.md`  | Quasi-potential dynamics, critical points, barrier heights, PDE integration |

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in the relevant `context/<name>.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR in `decisions/`, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0002 (Stage 2 dynamics estimator) — but worth reopening because…_
