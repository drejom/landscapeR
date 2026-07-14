# Implementation plan — issue #70 authoritative roadmap

> **Historical implementation record.** Status and sequencing in this file
> describe its originating work and are superseded for current scheduling by
> the root [`ROADMAP.md`](../../ROADMAP.md).

## Objective

Establish one living `ROADMAP.md` as the sole source for package sequencing and
cleanly separate source documentation, historical plans, archived audits, and
generated pkgdown output.

## Authority model

- `ROADMAP.md` owns scope, ordering, dependencies, active/queued/parked state,
  milestone gates, and the deterministic next task.
- GitHub issues own detailed work specifications and completion discussion.
- ADRs own algorithm and architecture decisions.
- `context/` and the ubiquitous language own domain orientation.
- `docs/specs/` owns frozen scientific/executable protocols.
- `docs/plans/` and `docs/archive/` are historical execution and audit records;
  they do not schedule work.
- pkgdown output is generated under `_site/` and deployed by CI; it is not
  tracked as source documentation.

## Work slices

1. Inventory source versus generated documentation and all open issues.
2. Draft the package-wide roadmap with high-resolution near-term AML Stage 1
   work and progressively lower-resolution later milestones.
3. Create the missing exploratory `primary_2018` Stage 1 execution issue and
   add it to the active milestone gate.
4. Reorganize historical plans/audits and remove tracked generated site output.
5. Add a documentation index and update all authoritative navigation surfaces.
6. Mark the old grilling sequence as historical/superseded for scheduling.
7. Validate issue coverage, relative links, roadmap invariants, pkgdown, package
   checks, and repository policy.
8. Open a PR with before/after information-architecture proof and cold-reader
   interpretation, then perform the repository two-axis review.

## Test seams

- Highest seam: a repository-level roadmap audit checks required headings,
  exactly one active next task, unique representation of open issues, and valid
  local Markdown links.
- Existing pkgdown build verifies generated-site integrity after tracked output
  is removed.
- Existing package, ADR, registry, and visual-proof policy checks remain
  unchanged.

## Visual landing proof

The PR will show:

- before: scheduling spread across audit prose, issues, and development-log
  status plus generated/source files mixed in `docs/`;
- after: one root roadmap, one documented source taxonomy, organized historical
  records, and generated site output only under `_site/`/CI;
- claim status: developer-workflow/documentation proof only; no scientific
  acceptance status changes.

## Completion evidence

- Created the missing terminal AML Stage 1 execution issue (#71).
- `scripts/check-roadmap.py` validates the authority declaration, one next task,
  unique issue rows, live open-issue coverage, non-stale closed rows, and local
  links across source documents.
- 31 repository policy CLI contract tests passed.
- 456 R assertions passed.
- ADR coverage and registry compliance passed.
- pkgdown rebuilt successfully under `_site/`; both article image audits passed,
  and the rendered navbar/home page expose the authoritative roadmap.
- Full package build/check completed with the existing local
  `MultiAssayExperiment` R-version warning and benchmark-path NOTE only.
- PR proof is recorded under `.github/landing-proof/issue-70/README.md`.
