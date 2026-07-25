# ADR 0020 expert-review record

**Status:** human review open; provisional implementation may proceed
**Questionnaire:** `landscaper-scientific-consultation-v2`
**Hosted form:** <https://tally.so/r/NpQ2g0>
**Decision under review:** [`decisions/0020-stage1-component-interpretation-statistical-strategy.md`](../../decisions/0020-stage1-component-interpretation-statistical-strategy.md)

## Recording policy

- Tally submissions and review correspondence remain private to the project team.
- Responses are not published, quoted, or attributed without separate permission from the reviewer.
- Each response is retained individually and is not reduced to a majority vote.
- Substantive disagreement and unresolved objections are preserved in the private review record.
- The public ADR may describe resulting methodological changes and unresolved scientific questions without identifying or quoting reviewers.
- An implementation-blocking objection must be resolved, explicitly retained with rationale, or sent for re-review before ADR 0020 can be accepted.
- Non-response is not recorded as support.

## Review status

Two invitations have been sent. Human responses remain pending; none has yet
been received. Non-response is not support, and later substantive feedback can
reopen the provisional decision.

An ephemeral AI-assisted adversarial sanity check was used to surface possible
failure modes. It was not treated as expert review, its raw responses and model
lineage are not retained as project evidence, and apparent consensus was not
counted. Two substantive questions—cross-sectional adjusted-rank interpretation
and rank-transformed time interactions—were resolved against primary methods
literature in
[`docs/research/adr-0020-rank-association-and-time-interaction-methods.md`](../research/adr-0020-rank-association-and-time-interaction-methods.md).

## Private response index

_Do not add reviewer identities, quotations, or response details to this public repository. Maintain the private response index alongside the raw Tally export._

## Decision-resolution audit

| Decision | Feedback received | Change made | Remaining objection | Ready for acceptance |
|---|---|---|---|---|
| 1. Sampling dependence and time | Human response pending | Reaffirmed orthogonal dependence/time design; pointed to ADR 0009 upstream technical-replicate boundary | None from sanity check | provisional |
| 2. Rank association estimands | Human response pending | Renamed and defined residualized marginal-rank projection estimand; bootstrap uncertainty only | Human assessment pending | provisional |
| 3. Independent/repeated time models | Human response pending | Replaced naive global-rank interactions with standardized score-scale linear/mixed slope contrasts | Human assessment pending | provisional |
| 4. Proposal ranking and multi-layer abstention | Human response pending | Retained effect-only point rank and no runner-up promotion; added visible gap/tie diagnostic | Human assessment pending | provisional |
| 5. Resampling and component alignment | Human response pending | Retained global assignment/no Procrustes; added assignment-strength and unmatched-axis evidence | Human assessment pending | provisional |
| 6. Evidence and confirmation boundary | Human response pending | Expanded null, confounding, near-degeneracy, misspecification, and abstention validation requirements | Human assessment pending | provisional |
