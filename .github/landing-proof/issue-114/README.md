# Issue #114 landing proof

These representative 100 mm square figures verify that moving Stage 1 and
Stage 2 display calculations into stored `StagePlotEvidence` preserves the
publication visual grammar and separate scientific captions.

Run:

```sh
Rscript scripts/render-issue-114-proof.R
```

The proof records:

- one PNG and external caption for each migrated plot family;
- `inspection.tsv`, confirming canonical dimensions and that captions remain
  outside the graphics; and
- `evidence.tsv`, identifying the digest-bound Stage 1 and Stage 2 evidence
  objects consumed by the renderers.

The component gallery draws stored pooled densities for unlabelled and
continuous-metadata views. Categorical views draw stored group-specific
density curves and aligned sample-coordinate rugs; neither density surface is
estimated by the renderer.
