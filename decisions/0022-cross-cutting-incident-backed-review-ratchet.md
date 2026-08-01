# 0022 — Incident-backed review ratchet

**Stage:** cross-cutting
**Status:** accepted
**Date:** 2026-07-31

## Context

Agents start with incomplete session context. Review findings can therefore be
rediscovered, asynchronous reviewers can report after an apparently green merge
gate, and stale guidance can retain authority after the code changes. Tests only
cover behavior the project already understood. Review knowledge needs a bounded,
repository-owned memory without becoming a second style guide or decision log.

## Options considered

| Option | Source / reference | Key property | Disqualifier or concern |
|---|---|---|---|
| Session transcripts only | Previous workflow | No repository maintenance | Cold-start agents cannot rely on it |
| Append-only review notes | Common living-document pattern | Easy to add | Rot becomes authoritative and contradictions accumulate |
| Incident-backed ratchet with executable bounds | Issue #138 | Adds, corrects, deduplicates, and graduates knowledge | Requires small maintenance duty in each PR |

## Criteria

- Review knowledge must survive sessions and remain discoverable.
- Every earned rule must be traceable to a concrete repository incident.
- Wrong or obsolete rules must be corrected or removed.
- Mechanically enforceable rules must graduate into automation.
- The document must remain short enough to be read.
- Reviewer findings must remain claims to verify, not commands to obey.

## Evidence

PR #137 demonstrated two relevant failures: actual GitHub Copilot findings
arrived after the internal review passes, and a shell-interpreted Markdown reply
was corrupted while documenting a fix. The repository had no durable review
memory or merge gate covering either class.

## Decision

**Chosen:** one incident-backed review ratchet with a single executable policy
seam.

`docs/agents/review-ratchet.md` owns the merge sequence and earned review ledger.
Agents add a new defect class only with a concrete incident, correct or remove
stale entries, deduplicate before adding, and report one ratchet disposition in
each pull request. The document is capped at 150 lines. Mechanical rules
graduate into checks; architectural or scientific decisions graduate into ADRs.
One checker validates the document contract and pull-request disposition in CI,
and validates the document locally in pre-push.

## Implementation landing proof

- **Proof classification:** required
- **Before/after or representative output:** render the enforced merge sequence,
  one incident-backed entry, and passing/failing checker output
- **Current documentation affected:** agent guidance and documentation authority map
- **Claim status:** cross-cutting developer-workflow enforcement

## Consequences

- Review knowledge becomes cumulative and inspectable.
- Pull requests cannot silently omit their ratchet maintenance decision.
- Semantic contradiction and applicability checks remain human or agent review
  duties; the checker does not pretend to understand prose.
- The ledger cannot hold implementation conventions, domain vocabulary,
  session history, or one-off decisions.
- Maintenance adds a short review step, offset by fewer repeated defects.

## Review trigger

Revisit if the document exceeds 150 lines, agents routinely skip relevant
entries, incident references cease to be auditable, or a better repository-wide
knowledge mechanism preserves correction and graduation duties.
