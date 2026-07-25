# GitHub Copilot instructions for landscapeR

## Repository purpose and authority

`landscapeR` is an R package for multi-layer omic state-transition analysis. It
combines comparative decomposition with quasi-potential dynamics using a
contract-based S4 architecture.

- Read `CLAUDE.md` before changing code. It is the detailed architecture and
  repository orientation.
- Treat `ROADMAP.md` as the sole authority for scope, sequencing, dependencies,
  and the next task. Do not infer priority from issue numbers or old plans.
- Read `decisions/README.md` and the relevant ADRs before making an algorithm,
  dependency, schema, or scientific-policy choice.
- Use `docs/README.md` to locate current specifications and documentation.
- Preserve user changes and avoid unrelated refactors.

## Architecture and scientific guardrails

- Program to the VIRTUAL S4 contracts and keep `StateTransitionData` as the
  container passed between stages.
- Validate public boundaries and return landscapeR typed failures. Do not leak
  incidental base or dependency errors from public workflows.
- Keep stage functions deterministic and pure. Seed every stochastic operation.
- Select algorithms through the strategy registry. Do not introduce
  `if (method == ...)` dispatch.
- Record provenance for every scientific artifact and preserve stable,
  serializable typed results.
- Keep decomposition outcome-blind. Metadata may interpret frozen coordinates
  through the declared atlas, proposal, abstention, and explicit human
  confirmation workflow; it must not silently relabel or refit the state space.
- Never promote a runner-up after an exploratory proposal fails. Return a typed
  abstention unless a separately predeclared human decision boundary applies.
- Do not weaken sampling-unit assumptions, treat repeated observations as
  independent, or treat technical replicates as biological replicates.
- Define scientific criteria before inspecting results. Stage 0 known-truth
  controls are the evidence oracle for algorithm claims and thresholds.
- Do not hard-code biological thresholds, critical-point locations, smoothing
  degree, or bandwidth. Do not claim support beyond the recorded evidence tier.
- Do not change `schema_version` without a registered migration.

## Implementation conventions

- Support R 4.3 or newer on macOS and Linux. Windows is explicitly unsupported.
- Follow the existing numbered file layout and update `DESCRIPTION` `Collate`
  when adding an R source file.
- Use roxygen2 comments as the source for public documentation. Regenerate
  `NAMESPACE` and `man/*.Rd`; do not hand-edit generated files.
- Add or update `testthat` coverage with every behavior change. Include failure
  paths, deterministic orientation, provenance, digest, and serialization
  checks when relevant.
- Use package-owned `ggplot2` helpers for public figures. Preserve the quiet
  black, white, and grey grammar, with red reserved for the declared focal
  contrast. Expose ambiguity and missingness rather than hiding them.
- Qualifying implementation work requires the visual landing proof described
  by ADR 0017 and current public workflow documentation.
- Keep generated sites, local plots, and temporary analysis products out of Git
  unless a documented evidence or landing-proof path requires them.

## Validate changes

Run focused tests while developing, then run the complete local gate:

```sh
Rscript -e 'devtools::test(stop_on_failure = TRUE)'
python3 scripts/check-adr-coverage.py
bash scripts/check-registry-compliance.sh
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
Rscript -e 'pkgdown::build_site()'
```

For package-level verification, mirror CI:

```sh
Rscript -e 'rcmdcheck::rcmdcheck(args = c("--no-manual"), error_on = "warning")'
```

CI uses R 4.5 and Bioconductor 3.22. A pull request must pass R CMD check,
pkgdown, article-image validation, roadmap integrity, ADR coverage, registry
compliance, visual-proof policy, and security checks.

Before declaring work complete:

1. Inspect the rendered public output, not only tests or source code.
2. Review the complete diff for architectural and scientific contract drift.
3. Address every actionable pull-request review comment and explain the
   resolution on its thread.
4. Confirm the worktree is clean and all required checks are green.

Trust these instructions and the named repository authorities. Search further
only when they are incomplete, inconsistent, or demonstrably stale.
