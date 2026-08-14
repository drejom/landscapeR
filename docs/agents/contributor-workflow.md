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
- Contributors adding a design-aware K=1 calibration module follow the
  scientific-module and shared publication boundaries in
  [`docs/architecture/k1-calibration-modules.md`](../architecture/k1-calibration-modules.md).

## Install the safeguards

After cloning, install the versioned Git hooks once:

```sh
bash install-hooks.sh
```

The pre-push hook uses the same changed-file classifier as CI to choose a
source-affecting or documentation-only path. It is a faster local subset, not a
complete reproduction of the full CI job: source-affecting pushes run
`devtools::test()` and relevant policy checks, while CI additionally runs
`R CMD check`, builds pkgdown, and validates article images. The hook always
checks roadmap integrity, ADR governance, repository hygiene, and the review
ratchet. Do not use `[skip-hooks]` except for a documented emergency; the
remote CI gates still apply.

## Local safeguard and CI-parity commands

The ordinary fast safeguard path is a normal `git push` with the installed
hook. Its manual diagnostic commands are:

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

For full local parity with the source-affecting CI job, install the development
dependencies and run:

```sh
Rscript -e 'rcmdcheck::rcmdcheck(args = c("--no-manual"), error_on = "warning")'
bash scripts/build-pkgdown-site.sh
python3 scripts/check-pkgdown-images.py --site-root .scratch/site .scratch/site/articles/development-log.html
python3 scripts/check-pkgdown-images.py --site-root .scratch/site .scratch/site/articles/stage1-evidence.html
```

The pkgdown build and image checks are required locally whenever current
documentation changes. CI remains the authoritative environment because its R
version and dependency installation are defined by
`.github/workflows/R-CMD-check.yaml`.

Pull-request body checks for visual landing proof and ratchet disposition run in
CI because the local pre-push hook has no authoritative PR body. Validate a
prepared body after its final commit with
`scripts/check-figure-review.py PR_BODY_FILE --expected-commit FULL_HEAD_SHA`
and `scripts/check-review-ratchet.py --pr-body PR_BODY_FILE` before opening or
updating the PR. Repository-hosted proof links must contain that full head SHA,
not a feature-branch name, so the review record survives branch deletion.

## Before requesting merge

Follow the ordered gate in the review-ratchet guide. In particular, wait for
the actual GitHub Copilot response, investigate every finding, require green
CI and zero unresolved threads, and leave no untracked residue outside
`.scratch/`.
