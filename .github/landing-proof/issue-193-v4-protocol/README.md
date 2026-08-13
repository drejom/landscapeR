# Issue #193 v4 protocol refreeze proof

The frozen protocol objects produce the following reviewed comparison. Version
4 changes the RNG governance boundary only; the scientific contract remains
identical and neither version can execute acceptance work from this API.

| Contract surface | Version 3 | Version 4 | Reviewed conclusion |
|---|---|---|---|
| Scientific grids, thresholds, outcomes, pass rules, resampling, workload, execution contracts | Frozen v3 values | Byte-identical R objects | No scientific setting changed |
| Requested replicates | 7,200 | 7,200 | Workload unchanged |
| Acceptance execution available | `FALSE` | `FALSE` | Protocol construction cannot run tasks |
| Seed reveal | v3 merge, now retired | Hidden until reviewed v4 merge | No v4 seed exists in this PR |
| Historical calibration RNG | Opaque digest references | Canonical task IDs, complete L'Ecuyer states, named child seeds, and verified payload digests | Historical RNG is reproducible before v4 seed reveal |
| Version 3 acceptance block | Revealed after v3 merge | Scalars 664979464 through 665037063 reserved in full | Prematurely exercised v3 evidence cannot enter v4 |

Reproduce the comparison and validation with:

```sh
Rscript -e 'devtools::test(filter="stage0-k1-acceptance-protocol", reporter="summary")'
```

Claim status: implementation proof for a predeclared, definition-only protocol.
It is not acceptance evidence and reports no scientific result.
