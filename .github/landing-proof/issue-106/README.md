# Issue #106 scientific-caption contract proof

This proof shows that one typed formatting contract can describe complete,
partial, and abstention outcomes while preserving the requested biological
resampling denominator. The caption is saved separately from the ordinary
ggplot and contains exact declared experimental context, encodings, design,
threshold status, and claim boundary.

Regenerate from the repository root:

```sh
Rscript scripts/render-issue-106-proof.R
```

Artifacts:

- `caption-contract.png`: canonical 100 mm implementation proof.
- `caption-contract-caption.txt`: the exact output of
  `scientific_caption(plot)`.
- `caption-contract-states.tsv`: the stored facts rendered in the proof.

Claim status: architecture and implementation proof only.

Validation:

- focused scientific-caption contract: 36 assertions passed;
- full source-loaded suite: 1,638 passed, 0 failed, 1 expected skip;
- ADR coverage, strategy-registry compliance, visual-proof policy tests, and
  roadmap integrity passed;
- the PNG was inspected at its canonical 100 mm size and the separate caption
  was read as a publication artifact.
