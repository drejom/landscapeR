# 0021 — Repository hygiene and ephemeral artifacts

**Stage:** cross-cutting
**Status:** accepted
**Date:** 2026-07-31

## Context

landscapeR agents, development tools, prototypes, package builds, plotting
workflows, and runtime experiments create files that are not package source or
governed scientific artifacts. The repository previously relied on scattered
`.gitignore` entries and informal cleanup. That arrangement hid some residue
without defining where transient state belongs or making violations visible.

The policy must cover scratch files, local runtime state, built bundles,
screenshots, prototype databases, and analogous ephemeral output. It must also
distinguish transient output from governed artifacts with retention, access, or
audit rules.

ADR 0014 contains a dangling reference to ADR 0013 at line 38. No ADR 0013 is
present. That is a pre-existing, unrelated governance gap and this decision
does not silently allocate, reconstruct, or fill ADR 0013.

## Options considered

| Option | Source / reference | Key property | Disqualifier or concern |
|---|---|---|---|
| `.gitignore` alone | Previous repository practice | Hides known paths from status | Hides residue instead of preventing it; this allowed a tracked `.claude-notes.md` to claim incorrectly that it was gitignored |
| Rely on code review | Ordinary pull-request review | No additional tooling | Untracked files never appear in a diff and are therefore invisible to review |
| Per-directory scratch conventions | Module-local output folders | Keeps output near its producer | Reproduces the hunt for transient state and prevents whole-prototype cleanup without internal knowledge |
| One configured scratch root plus executable verification | This decision | One removable location and immediate violation feedback | Adds one CI/pre-push check and requires output paths to be configurable |

## Criteria

- Every package-owned ephemeral artifact has one predictable default location.
- Removing prototype state does not require understanding prototype internals.
- Scientific modules do not write transient state into their source trees.
- Governed artifacts cannot be mistaken for disposable output.
- Agent completion includes a clean worktree, not an informal cleanup promise.
- Violations are detected at the developer workflow seam rather than relying on
  review of tracked diffs.
- Existing external-tool runtime directories remain explicit compatibility
  exceptions, not precedents for new module-local scratch conventions.

## Evidence

No scientific Stage 0 evidence applies to this process decision. The concrete
repository incident is `.claude-notes.md`: it is tracked while its own header
claimed “Gitignored — not part of the package.” The existing ignore list also
contains separate agent/tool scratch paths, while the installed pre-push hook
and its installer were not linked from agent-facing documentation. These are
exactly the discoverability and silent-drift failures this policy is intended
to prevent.

## Decision

**Chosen:** one configured repository scratch root, `.scratch/`, backed by an
executable untracked-file check shared by CI and the pre-push hook.

The following rules are normative:

1. **One designated transient location.** All package-owned ephemeral output,
   including scratch files, local runtime state, built bundles, screenshots,
   and prototype databases, goes under the repository-root `.scratch/`
   directory. `.scratch/` is gitignored. No module writes transient state into
   its own source tree.
2. **Transient paths are configured, not hardcoded.** Code resolves its output
   location from configuration and defaults to the scratch root. A prototype's
   complete state must be removable without knowing its internals.
3. **Agents clean up after themselves.** An agent that creates files outside
   `.scratch/` either commits them deliberately or removes them before
   finishing. Untracked residue is a defect, not housekeeping.
4. **Anything governed is never transient.** An artifact subject to audit,
   credential, retention, access, privacy, scientific-evidence, or other
   controlled-artifact rules is stored only at its declared governed location
   under those rules, or is not produced. It is never a loose file outside
   policy and never placed in `.scratch/` to evade governance.
5. **Enforce it executably.** A repository checker fails when `git status
   --porcelain` reports an untracked, non-ignored path outside `.scratch/`.
   CI runs the checker in the lint job and the pre-push hook runs the same
   script locally. The local check is load-bearing because files absent from a
   pushed commit cannot be reconstructed by CI.

Existing ignored directories owned by external development tools, including
`.pi-subagents/`, `.claude/`, and `.playwright-mcp/`, remain explicit
compatibility exceptions. They do not authorize new package modules or
prototypes to create additional scratch roots. New exceptions require an
amendment to this decision and corresponding checker/documentation changes.

## Implementation landing proof

- **Proof classification:** exempt
- **Before/after or representative output:** checker tests demonstrate clean,
  `.scratch/`, ignored-tool, and unexpected-untracked worktrees
- **Current documentation affected:** `docs/agents/repo-hygiene.md`, the agent
  skills index, and the documentation authority table
- **Claim status:** internal developer-workflow policy and enforcement only
- **Exemption category and rationale:** internal-only; the change has no
  scientific, package-user, data, plotting, or public analysis surface. Its
  observable behavior is confined to repository agents, CI, and local hooks.

This is implementation proof, not a substitute for immutable scientific
acceptance evidence.

## Consequences

- A prototype or failed session can be removed by deleting one configured
  subtree.
- Agents and maintainers see unexpected residue before work is pushed.
- Modules must accept or derive output configuration instead of embedding
  source-relative transient paths.
- Governed scientific and operational artifacts remain subject to their own
  stronger locations and policies.
- The checker cannot discover a developer's untracked local file after it has
  been omitted from a push; local pre-push enforcement therefore remains
  necessary even though the same check runs in CI.
- External tools with fixed repository-local state retain a small documented
  exception set.

## Review trigger

Revisit if a required development tool cannot use `.scratch/` and needs a new
fixed repository-local path, if a governed artifact class lacks an authoritative
storage policy, or if Git gains a reliable server-side mechanism for observing
the contributor's untracked local worktree.
