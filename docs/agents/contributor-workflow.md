# Contributor workflow and local safeguards

This guide makes the repository's contributor safeguards discoverable. It does
not define scientific methods, architecture, or scheduling.

## Authorities

- [`ROADMAP.md`](../../ROADMAP.md) alone owns package sequence, milestone state,
  dependencies, and the next task.
- A GitHub issue specifies one deliverable; it does not reorder the roadmap.
- [`decisions/`](../../decisions/README.md) owns accepted algorithm and
  architecture choices.
- [`docs/architecture/`](../architecture/) records current module ownership and
  dependency direction without replacing ADRs.
- [`docs/agents/review-ratchet.md`](review-ratchet.md) owns the merge-gate
  sequence and incident-backed review lessons.
- [`docs/agents/repo-hygiene.md`](repo-hygiene.md) owns transient-output policy.

## Install the safeguards

After cloning, install the versioned Git hooks once:

```sh
bash install-hooks.sh
```

The pre-push hook selects the same full-package or documentation-only path as
CI from the changed files. It always checks roadmap integrity, ADR governance,
repository hygiene, and the review ratchet. Source-affecting changes also run
the package tests and relevant ADR/registry checks. Do not use `[skip-hooks]`
except for a documented emergency; the remote CI gates still apply.

## Local CI-parity commands

The ordinary parity path is a normal `git push` with the installed hook. For a
manual diagnostic run, use the same underlying commands:

```sh
Rscript -e 'devtools::test()'
python3 scripts/check-adr-coverage.py
python3 scripts/check-adr-governance.py
bash scripts/check-registry-compliance.sh
bash scripts/check-repo-hygiene.sh
python3 scripts/check-review-ratchet.py
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
```

Roadmap parity additionally requires live GitHub issue state:

```sh
gh issue list --repo drejom/landscapeR --state open --limit 200 --json number > /tmp/open-issues.json
python3 scripts/check-roadmap.py --open-issues-json /tmp/open-issues.json
```

When current documentation changes, also run:

```sh
bash scripts/build-pkgdown-site.sh
```

Pull-request body checks for visual landing proof and ratchet disposition run in
CI because the local pre-push hook has no authoritative PR body. Validate a
prepared body explicitly with `scripts/check-figure-review.py` and
`scripts/check-review-ratchet.py --pr-body` before opening the PR.

## Before requesting merge

Follow the ordered gate in the review-ratchet guide. In particular, wait for
the actual GitHub Copilot response, investigate every finding, require green
CI and zero unresolved threads, and leave no untracked residue outside
`.scratch/`.
