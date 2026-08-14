# Issue 210 landing proof

Cross-sectional and independent destructive-time-course interpretation now
cross one normalized execution kernel while retaining different scientific
estimands, cohort rules, diagnostics, and resampling designs.

![Two design-specific analysis lanes entering the same normalized association execution kernel, then retaining distinct scientific evidence outputs.](association-execution-kernel.png)

**Figure. Shared execution without scientific homogenization.** The upper lane
shows cross-sectional rank association and independent-observation bootstrap.
The lower lane shows the condition-by-time interaction and condition-by-time
cell bootstrap. Both lanes use the same validated strategy resolution,
component traversal, accounting, multiplicity, abstention propagation, and
atlas assembly. The kernel does not choose an estimand or exchangeability rule.

[`evidence-equivalence.tsv`](evidence-equivalence.tsv) records the frozen atlas
identities for successful and partial cases, plus the typed non-identifiable
outcome. Regenerate both artifacts from the repository root with:

```sh
Rscript scripts/render-issue-210-proof.R
```

This is architecture and implementation proof. It does not establish
scientific recovery, component identifiability, or an acceptance threshold.
