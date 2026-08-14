# Issue 209 landing proof

Both scientific workflows now enter one filesystem publication module while
retaining separate scientific adapters.

```mermaid
flowchart LR
  C[Design-aware K=1 calibration adapter] --> P[Immutable artifact publication module]
  R[Revised K=1 acceptance adapter] --> P
  P --> S[Complete staged payload]
  S --> M[Exact SHA-256 manifest]
  M --> V[Generic integrity verification]
  V --> R2[Adapter semantic replay]
  R2 --> A[Atomic content-addressed publish]
```

The module rejects missing, duplicate, altered, and undeclared files. The
adapters still own scientific validation, claim status, input identity, RNG
identity, plots, captions, and semantic replay. Runtime telemetry remains
outside the scientific digest.

[`publication-verification.tsv`](publication-verification.tsv) records a
reproducible publication, deterministic address reuse, and rejection of a
mutated payload. Regenerate it from the repository root with:

```sh
Rscript scripts/render-issue-209-proof.R
```

This is architecture and implementation proof. It does not establish or alter
any scientific acceptance threshold.
