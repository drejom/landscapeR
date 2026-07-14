# Issue Tracker

Issues for this project live in **GitHub Issues** at `drejom/landscapeR`.

## Scheduling authority

GitHub issues specify individual deliverables; they are not the work schedule.
The root [`ROADMAP.md`](../../ROADMAP.md) is the sole authority for milestone
order, dependencies, active/queued/parked state, and the next task. Never select
work from issue number, label, recency, or an archived implementation plan.

When an issue or PR changes sequencing, blocking status, milestone scope, or the
canonical roadmap issue register, update `ROADMAP.md` in the same PR. A closing
PR marks its row `complete on merge` and advances exactly one next task before
merge. A new issue or ADR does not reorder work by itself.

Use the `gh` CLI for all read/write operations:

```bash
gh issue list --repo drejom/landscapeR
gh issue view <number> --repo drejom/landscapeR
gh issue create --repo drejom/landscapeR --title "..." --body "..."
gh issue close <number> --repo drejom/landscapeR --comment "..."
gh issue edit <number> --repo drejom/landscapeR --add-label "..."
```

## Visual landing-proof field

Every implementation issue must classify its landing proof before it receives
`ready-for-agent`:

```markdown
## Visual landing proof

- **Classification:** required | exempt
- **Proof:** before/after for a fix, or representative figure/table/workflow
  render for a capability
- **Current documentation:** affected vignette/README, or why unaffected
- **Claim status:** implementation proof, exploratory, calibration-only,
  accepted evidence, etc.
- **Exemption:** internal-only | research/decision-only, with rationale
```

Qualifying surfaces are scientific behavior, public APIs, user-visible behavior,
plotting, prepared data/schema, and developer-facing workflows. Exemptions are
limited to internal-only work with no observable surface and research/decision-
only phases that prohibit implementation. A deferred exemption expires when
implementation begins. Generic `N/A` is invalid.

Do not close a qualifying issue until its pull request contains the proof packet,
current documentation is updated when affected, and the rendered output has
been inspected. Pull-request proof is not immutable scientific evidence.

## PR surface

External PRs are **not** a triage surface. This is a research package with no external contributors — all PRs are from the maintainer or collaborators. Do not pull external PRs into the triage queue. Qualifying implementation work nevertheless lands through a branch and reviewed PR because that PR is the canonical visual transition record.
