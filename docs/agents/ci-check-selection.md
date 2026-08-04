# CI package-check selection

Every pull request reports the named `R-CMD-check` job. The job uses
`scripts/classify-package-check.py` to choose one of two paths:

- `full`: install R and package dependencies, run `R CMD check`, build pkgdown,
  and validate article images;
- `docs-only`: retain the required job but skip package installation and
  execution because every changed path is documentation-only.

The policy is fail-safe. R source, tests, `DESCRIPTION`, `NAMESPACE`, generated
reference files under `man/`, vignettes, workflow files, scripts, data, mixed
diffs, empty diffs, and unrecognized paths select `full`. Markdown and source
documentation under `docs/`, `decisions/`, `context/`, and landing-proof paths
may use `docs-only`. Non-executing GitHub issue-template Markdown and YAML may
also use the short path; workflow YAML remains full-path.

Labels do not select package checks. The pre-push hook sends its changed-file
set through the same classifier and runs package tests whenever `full` is
selected. To inspect a decision locally:

```sh
printf '%s\n' R/runner.R docs/README.md |
  python3 scripts/classify-package-check.py --stdin
```

Adding a new documentation-only path requires a policy change with tests. New
or unknown execution-affecting paths need no allowlist change because they
already select the full path.
