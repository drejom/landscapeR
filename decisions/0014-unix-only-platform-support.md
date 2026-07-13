# ADR 0014 — Unix-only platform support (macOS and Linux)

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-07-13 |
| Deciders | Dom O'Meally |
| Issue | #45 review (Gemini) |

## Context

The Stage 1 execution module (`R/23-stage1-execution.R`) uses:

- Atomic `file.rename` to publish task checkpoints — semantics differ on Windows
  (rename over an existing destination fails).
- A Unix process-liveness signal (`SIGKILL 0`) via `tools::pskill` to detect stale
  workspace coordinator locks — `tools::pskill` on Windows ignores the signal
  argument and unconditionally terminates the target, making a signal-0 liveness
  probe impossible without platform-specific workarounds.
- `parallel::mcparallel` for non-Darwin Unix parallel execution — not available on
  Windows.
- `tools::pskill(job$pid, 9L)` in `on.exit` cleanup of orphaned workers — safe on
  Unix; semantics uncertain on Windows.

Code review on PR #45 (Gemini) surfaced two of these as critical/medium bugs and
proposed Windows-specific workarounds (`tasklist`, backup-rename). Addressing them
correctly would permanently bifurcate the workspace-management logic into Unix and
Windows branches, each with its own failure modes.

## Decision

landscapeR explicitly supports **macOS and Linux only**.  Windows is not a
supported platform.

Rationale:

1. **Target environment.** The package is used by bioinformaticians doing
   multi-omic analysis.  Production HPC runs on Linux (see ADR 0013).  Active
   development occurs on macOS.  Windows is not in either path.

2. **Complexity cost.** Windows requires fundamentally different implementations
   of atomic file publishing, process liveness, and parallel worker management.
   Each workaround adds a permanent maintenance branch and a separate test matrix.

3. **Honest scope.** The package makes no claim of broad distribution or CRAN
   submission.  Documenting the real constraint is preferable to accumulating
   half-correct Windows compatibility code.

## Consequences

- `DESCRIPTION` gains `SystemRequirements: Unix-like OS (Linux or macOS)`.
- `execute_stage1_benchmark_full()` and `execute_stage1_benchmark_development()`
  each call `.stage1_assert_unix_platform()` at the top, aborting with a typed
  `stage1_execution_error` before touching any workspace state. The check uses
  `Sys.info()[["sysname"]]` and accepts only `"Darwin"` and `"Linux"`, matching
  the stated support matrix precisely (FreeBSD and other Unix-likes are also
  excluded).
- The `file.remove()` Windows guard in `.stage1_atomic_save_rds` (added in PR #45)
  is removed; the function now documents its Unix assumption.
- The `tools::pskill(pid, 0L)` liveness probe is kept as-is; the Windows
  `pskill`-kills-the-process caveat is irrelevant because Windows is not a
  supported platform.
- The existing `"parallel execution requires a Unix-like platform"` abort in
  `.stage1_execute_checkpointed_tasks` is superseded by the earlier platform gate.
- pkgdown reference and README note the macOS/Linux constraint.
