# Documentation map

This directory contains **source documentation only**. Generated pkgdown output
is built under `.scratch/site/` and deployed by CI; it is not committed here.

## Authority and purpose

| Surface | Owns | Does not own |
|---|---|---|
| [`ROADMAP.md`](../ROADMAP.md) | Package scope, milestone sequence, dependencies, active/queued/parked state, next task | Issue-level implementation detail or algorithm decisions |
| [GitHub Issues](https://github.com/drejom/landscapeR/issues) | One deliverable's specification, discussion, and completion | Package-wide priority or schedule |
| [`decisions/`](../decisions/README.md) | Algorithm and architecture choices, criteria, evidence, consequences | Work scheduling |
| [`context/`](../CONTEXT-MAP.md) | Stage/domain orientation and relationships | Decisions or scheduling |
| [`UBIQUITOUS_LANGUAGE.md`](../UBIQUITOUS_LANGUAGE.md) | Canonical domain terminology | Work scheduling |
| [`specs/`](specs/) | Frozen scientific and executable protocols | General roadmap status |
| [`plans/`](plans/) | Per-issue execution plans and completion evidence | Current package priority |
| [`research/`](research/) | Primary-source methodological research notes that inform decisions | Algorithm decisions or acceptance status |
| [`reviews/`](reviews/) | Versioned expert-consultation instruments, hosted-form manifests, and private-review protocols | Reviewer identities, raw responses, or quotations |
| [`architecture/`](architecture/) | Current package module seams, owned invariants, and dependency direction | Algorithm choice or work scheduling |
| [`archive/`](archive/) | Completed audits and superseded planning context | Current package priority |
| [`agents/`](agents/) | Agent workflow and issue/triage guidance | Scientific decisions |
| [`agents/repo-hygiene.md`](agents/repo-hygiene.md) | Transient-output location, governed-artifact distinction, agent cleanup, and executable hygiene checks | Scientific artifacts or retention policy definitions |
| [`agents/review-ratchet.md`](agents/review-ratchet.md) | Mandatory review gate, incident-backed review knowledge, correction, deduplication, and graduation | Implementation conventions, domain vocabulary, scheduling, or decisions |
| [`agents/ci-check-selection.md`](agents/ci-check-selection.md) | Shared path policy for full package checks and the documentation-only short path | Scientific test content or branch-protection administration |
| [`agents/execution-reproducibility.md`](agents/execution-reproducibility.md) | Compute-tier meanings, run-seed derivation, future backend ownership, and repetition accounting | Scientific exchangeability rules or scheduler configuration |
| [`vignettes/`](../vignettes/) | Current user workflow, implementation status, and evidence presentation | Historical transition proof or scheduling |
| Pull requests | Visual landing proof co-located with a diff | Immutable scientific acceptance evidence |
| `inst/benchmarks/` | Immutable/content-addressed benchmark evidence | Development scheduling |

## Scheduling rule

Do not reconstruct “what is next?” from issue numbers, labels, the development
log, archived audits, or implementation plans. Read the root
[`ROADMAP.md`](../ROADMAP.md) and follow its deterministic next-task rule.

If an issue or ADR changes sequencing, update the roadmap in the same pull
request. Details may become more precise as a milestone approaches; later
milestones should remain deliberately sketched until their decisions are due.

## Generated documentation

The authoritative pkgdown configuration writes to `.scratch/site/`. The CI
workflow builds and checks that site on pull requests and deploys it from `main`.
Historical generated files under `docs/` were removed because they duplicated
root/source documents, obscured ownership, and mixed build output with planning
records.
