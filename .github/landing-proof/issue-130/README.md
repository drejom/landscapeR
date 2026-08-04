# Issue 130 package-check selection proof

## Path-to-check decision table

| Changed paths | Selected path | Required `R-CMD-check` job |
|---|---|---|
| `R/runner.R` | full | present; runs package check |
| `tests/testthat/test-runner.R` | full | present; runs package check |
| `DESCRIPTION`, `NAMESPACE`, or `man/run_pipeline.Rd` | full | present; runs package check |
| `README.md` and `docs/agents/ci-check-selection.md` | docs-only | present; records short-path success |
| `docs/README.md` plus `R/runner.R` | full | present; runs package check |
| unknown or empty path set | full | present; fails safe |

## Reproduction

```sh
python3 -m unittest scripts.tests.test_classify_package_check -v
```

## Representative workflow output

The workflow sends its NUL-delimited changed paths through the same command.
The implementation diff contains both a script and its tests, producing:

```text
$ printf '<changed paths as NUL-delimited input>' |
    python3 scripts/classify-package-check.py --stdin-zero --github-output "$GITHUB_OUTPUT"
full

$ cat "$GITHUB_OUTPUT"
run_full=true
scope=full
```

The pull request's `R-CMD-check` run is the live confirmation that the `full`
output activates dependency installation and package checking. This is
developer-workflow proof only; it makes no scientific claim.
