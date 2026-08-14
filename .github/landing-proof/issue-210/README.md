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
digests for the rank-only cross-sectional fixtures and complete scientific
payload comparisons for the fitted time-course fixtures, plus the typed
non-identifiable outcome. The retained payload fixtures cover the complete
scientific provenance tree, evidence tables, cohort membership, fitted model
summaries, rankings, resampling plan, and identity fields. Only the original
raw evidence digests, repetition-result byte digests, and runtime model-engine
version are removed. Their normalized underlying evidence, repetition values,
declared model engine, RNG identity, and scientific summaries remain in the
comparison. Text, structure, identities, and nonnumeric scientific values must
match exactly. Floating-point values use an absolute tolerance of `1e-6`.
The comparison checks every retained field recursively instead of reducing the
payload to a rounded digest. Tests show that platform-scale perturbations inside
the declared tolerance compare equal, while scientific changes of `1e-4` and
changes to formulas, specifications, resampling, fitted models, or association
evidence do not.

The fitted reference payloads come from the pinned pre-migration revision

`e8e0c5284156bcf2d5f7f8612d096738db7a1daa`. Their human-readable manifest is
[`association-execution-manifest.tsv`](../../../tests/testthat/fixtures/association-execution-manifest.tsv).
Regenerate them deliberately with:

```sh
Rscript tests/testthat/fixtures/generate-association-execution-reference.R
```

Changing the pinned revision changes the scientific baseline and therefore
requires explicit review; ordinary proof regeneration only reads these
fixtures.

Regenerate both artifacts from the repository root with:

```sh
Rscript scripts/render-issue-210-proof.R
```

This is architecture and implementation proof. It does not establish
scientific recovery, component identifiability, or an acceptance threshold.
