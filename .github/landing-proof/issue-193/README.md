# Issue #193 protocol-freeze landing proof

This proof shows the public version 3 contract before any independent
acceptance seed is derived. The four rows in
[`revised-acceptance-contract.csv`](revised-acceptance-contract.csv) are the
complete evidence families. Together they contain 72 declared cells and 7,200
requested replicates. Each cell has 100 independent replicates.

The single target-axis recovery gate is absolute feature-loading cosine of at
least 0.90. Downstream estimability is reported separately and conditionally
after recovery. The table does not contain a pass, supported region, or sample
size recommendation because this pull request freezes the question rather than
executing it.

[`protocol-identity.txt`](protocol-identity.txt) records the exact digest and
confirms that no acceptance result was inspected and execution is unavailable
before merge. Reproduce both files with:

```sh
Rscript scripts/render-issue-193-freeze-proof.R
```

Claim status: predeclared acceptance protocol only.
