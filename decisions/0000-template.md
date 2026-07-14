# NNNN — Title

**Stage:** (0 / 0.5 / 0.75 / 1 / 2 / cross-cutting)
**Status:** proposed | accepted | superseded-by NNNN | rejected
**Date:** YYYY-MM-DD

## Context

What is the decision space? What are the constraints (data shape, n per layer,
rank expectations, R-only boundary, Bioconductor compatibility, etc.)?
State the scientific and engineering requirements that the decision must satisfy.

## Options considered

| Option | Source / reference | Key property | Disqualifier or concern |
|---|---|---|---|
| ... | ... | ... | ... |

## Criteria

What does "better" mean here, defined before looking at results:

- ...

## Evidence

What did Stage 0 show, or what benchmarks / published results are we relying on?
If no Stage 0 data yet, say so explicitly — this is a provisional decision pending validation.

## Decision

**Chosen:** ...

One paragraph on why. Reference the criteria above. Do not justify by availability alone.

## Implementation landing proof

Declare how an eventual implementation will be made inspectable under ADR 0017:

- **Proof classification:** required | exempt
- **Before/after or representative output:** ...
- **Current documentation affected:** ...
- **Claim status:** ...
- **Exemption category and rationale:** internal-only | research/decision-only
  (required only when exempt; a deferred exemption expires when implementation
  begins)

This is implementation proof, not a substitute for immutable scientific
acceptance evidence.

## Consequences

- What becomes easier?
- What becomes harder or constrained?
- What must be true for this to hold (assumptions that could invalidate the decision)?

## Review trigger

Under what conditions should this decision be revisited?
(e.g., "if thinness sweep shows recovery fails below n=30 donors")
