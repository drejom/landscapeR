# Issue #51 phase-B1 landing proof: independent acceptance result

## Claim boundary

This is the verified result of the frozen protocol-v2 phase-B1 experiment. The
content-addressed artifact is
`k1-stage0-acceptance-v2-780f4b10ea21923a`. It contains all 16,100 requested
tasks and passes semantic artifact verification. The result does not establish
a supported operating range.

## Cold-reader conclusion

The generic recovery control did not reach the prespecified 90% replicate pass
rate in any tested sample-size and feature-count cell. Its best observed rate
was 78% at `n = 192`, `p = 100`, with a Wilson 95% lower bound of 68.9%.
Recovery was 0% at 10,000 and 20,000 features throughout the tested sample-size
range. False double-well topology reached 43.5% in pure noise and 45% in
single-well data, exceeding the prespecified 5% maximum. False target selection
remained at or below 2.5%, and all 100 shared-baseline missing-cell replicates
correctly abstained. The frozen aggregate therefore reports no supported
minimum sample size.

## Recovery and thinness surface

![Observed pass-rate surface across sample and feature counts](pass-rate-surface.png)

The red line is the frozen 90% pass-rate gate. Each panel exposes the complete
sample-count and feature-count grid. The scientific caption is stored in
[`pass-rate-caption.txt`](pass-rate-caption.txt).

## Negative-control surface

![Observed false-positive surface for pure-noise and single-well controls](false-positive-surface.png)

The four panels separate false topology from false metadata-target selection in
each negative control. The red line is the frozen 5% maximum. The separate
publication caption is in
[`false-positive-caption.txt`](false-positive-caption.txt).

## Frozen workload and supported-range boundary

| Lane | Grid cells | Replicates per cell | Tasks | Observed status |
|---|---:|---:|---:|---|
| Double-well recovery | 32 | 100 | 3,200 | no cell passed |
| Pure noise | 32 | 200 | 6,400 | false topology exceeded 5% |
| Single well | 32 | 200 | 6,400 | false topology exceeded 5% |
| Shared-baseline safety | 1 | 100 | 100 | all replicates correctly abstained |
| Synchronized AML | 9 | 100 | 900 | remains issue #67 |

All 97 phase-B1 cells are complete. The supported minimum is `NA` because no
sample count passed the positive and negative gates across the complete feature
grid. The complete cell table is retained in
[`cell-summary.csv`](cell-summary.csv).

## Execution and verification flow

```text
reviewed protocol-v2 merge
        |
        v
17,000-task deterministic manifest
        |
        +--> 16,100 phase-B1 scheduler branches
                  |
                  v
          sequential work within each branch
                  |
                  v
       all successes and failures collected
                  |
                  v
   recomputed summary + runtime-bound content address
                  |
                  v
       immutable files and semantic verification
```

Changing a stored summary while merely regenerating its file checksum fails
verification. The verifier reconstructs task membership from the frozen
manifest, validates every typed replicate, recomputes the summary and payload
address, and cross-checks runtime revision provenance.

## Execution provenance

Workers ran on Gemini from reviewed merge
`7772baef1f7a69db107721487b20456a45f53bfe`. The source bundle SHA-256 was
`725bd6f0a00382a711602969f53c1083ec5be39ca1510f36084eb7e752ace921`.
After all worker branches completed, three collector defects were found: targets
had flattened each typed replicate, and the metric validator rejected
legitimate missing landmark errors when a well or barrier was not recovered;
the Wilson bound also differed across platforms at the sixteenth decimal place.
The worker results were not changed or rerun. Tested collection-only fixes
preserved list iteration and accepted `NA` only where the corresponding
landmark was not estimable, then rounded the Wilson bound to 15 decimal places
before hashing. The artifact binds separate worker and collector identities,
including the exact recovery script and patch-file hashes. The user explicitly
approved this recovery, and the permanent fixes and regression tests are part
of this pull request.

## Reproduction

```sh
Rscript scripts/render-issue-51-phase-b1-proof.R
Rscript -e 'devtools::test(filter = "k1-stage0-acceptance")'
```

The governed collection procedure is
[`scripts/recover-issue-51-phase-b1-artifact.R`](../../../scripts/recover-issue-51-phase-b1-artifact.R).
