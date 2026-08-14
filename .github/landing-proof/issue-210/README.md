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

[`evidence-equivalence.tsv`](evidence-equivalence.tsv) records exact atlas
digests for the rank-only cross-sectional fixtures and portable scientific
fingerprints for the fitted time-course fixtures, plus the typed
non-identifiable outcome. The portable fingerprint retains the complete
scientific provenance tree, evidence tables, cohort membership, fitted model
summaries, rankings, resampling plan, and identity fields. Only the original
raw evidence digests are removed because they encode the platform-dependent
floating-point bytes replaced by the normalized content. Numeric values are
rounded to six decimal places: the test treats changes below `5e-7` as
serialization or BLAS noise and detects changes of `5e-6` or more. CI exposed
the Linux/macOS raw-byte divergence; this explicit boundary, rather than the
opaque digest difference, defines the portable comparison. Regenerate both
artifacts from the repository root with:

```sh
Rscript scripts/render-issue-210-proof.R
```

This is architecture and implementation proof. It does not establish
scientific recovery, component identifiability, or an acceptance threshold.
