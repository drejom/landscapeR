# Issue Tracker

Issues for this project live in **GitHub Issues** at `drejom/landscapeR`.

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
