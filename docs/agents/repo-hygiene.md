# Repository Hygiene

ADR 0021 governs transient output and cleanup for agents and developer tools.

## Transient root

Use the repository-root `.scratch/` directory for every package-owned
ephemeral artifact:

- scratch files and intermediate exports;
- local runtime or checkpoint state;
- built bundles and temporary rendered sites;
- screenshots and visual debugging output;
- prototype databases and throwaway fixtures.

`.scratch/` is gitignored. Create task-specific subdirectories beneath it and
pass those paths through configuration. Do not hardcode transient paths inside
`R/`, `tests/`, `scripts/`, `docs/`, `vignettes/`, or another module's source
tree.

External tools with fixed paths (`.pi-subagents/`, `.claude/`, and
`.playwright-mcp/`) are compatibility exceptions already recorded by ADR 0021.
They are not examples to copy.

## Agent completion rule

Before finishing:

1. Inspect `git status --short`.
2. Commit deliberate repository artifacts.
3. Remove untracked output created outside `.scratch/`.
4. Leave ongoing disposable state under a task-specific `.scratch/` subtree.

Unexpected untracked residue is a defect. Do not describe it as optional
housekeeping or leave it for another agent.

## Governed artifacts

Never route a governed artifact through `.scratch/` merely because it is
generated. Audit records, credentials, restricted data, immutable scientific
evidence, and anything with retention or access requirements must use their
declared governed locations and policies. If no governed location exists, do
not produce the artifact until that policy is defined.

## Executable check

Run the same check used by CI and the pre-push hook:

```sh
bash scripts/check-repo-hygiene.sh
```

It fails when Git reports an untracked, non-ignored path outside `.scratch/`.
Ignored external-tool paths remain invisible to the check by design.

Install the repository hooks once after cloning:

```sh
bash install-hooks.sh
```

The pre-push hook runs the hygiene check against the local worktree. This is
the enforcement point that can observe files which would never appear in a
GitHub pull-request diff.
