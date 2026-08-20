# Issue #242 setup-r retry proof

The R CMD check and pkgdown jobs use one repository-local composite action.
That action passes the declared R version and package-manager setting unchanged
to `r-lib/actions/setup-r@v2`. The first two attempts may fail without ending
the job; the third failure remains terminal.

The workflow's `setup-r-retry-contract` job executes the composite action with
controlled outcomes and verifies second-attempt recovery, third-attempt
recovery, and terminal failure after three errors. `retry-contract.txt` is the
compact cold-reader proof. `scripts/tests/test_setup_r_retry.py` locks the
runner-level fixture and production wiring in place.

The behavioral proof runs whenever this pull request is opened or synchronized.
Inspect the `setup-r-retry-contract` job and confirm that `Verify retry outcomes`
passes after the two recovery fixtures and the captured terminal-failure
fixture. After merge, the same evidence can be reproduced with a workflow
dispatch on `main`.

The separate static policy contract is reproduced with:

```sh
python3 -m unittest scripts.tests.test_setup_r_retry -v
```

Claim status: developer-workflow implementation proof; no scientific claim.
