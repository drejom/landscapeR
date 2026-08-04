# Issue 132 cross-design execution proof

| Scientific workload | Sampling unit retained | Shared execution evidence |
|---|---|---|
| Cross-sectional uncertainty | independent biological observation | typed bootstrap result |
| Independent-time uncertainty | condition-by-time cell | typed bootstrap result |
| Repeated-time uncertainty | complete subject trajectory | typed bootstrap result |
| Cross-sectional permutation | independent biological observation | typed complete-search result |
| Independent-time permutation | within-time label or reduced-model residual | typed complete-search result |
| Repeated-time permutation | between-subject condition assignment | typed complete-search result |

Installed-package tests run all three designs under sequential, two-worker,
and three-worker multisession plans with different scheduling values. The complete atlases,
proposals, execution records, failure accounting, and digests must be
identical. Focused tests also verify that requested, completed, and failed
counts retain every task. This is execution proof only; it does not calibrate
scientific acceptance thresholds or change any estimand, exchangeability rule,
ranking, or p-value formula.
