# Issue #70 visual landing proof

**Claim status:** developer-workflow/documentation implementation proof only. No
scientific acceptance status changes.

## Before and after — scheduling authority

| Maintainer question | Before | After |
|---|---|---|
| What is next? | Reconstruct an answer from issue dependencies, the completed grilling audit, development-log “planned” rows, and context prose. | Read the single bold **Next task** declaration in root `ROADMAP.md`. |
| What sets package order? | No surface explicitly dominated the others. | `ROADMAP.md` alone owns order, gates, milestone state, and scope; `docs/README.md` assigns every other surface one role. |
| How are open issues checked? | Manual comparison. | `scripts/check-roadmap.py` fails on missing/duplicate issue rows, multiple next tasks, stale non-complete rows, or broken source-document links; CI compares it with live open issues. |
| What happens when sequencing changes? | The change could land in an issue or ADR without updating a package-wide schedule. | The issue and PR templates require roadmap placement/change control, and the roadmap states the same-PR maintenance rule. |

## Before and after — tracked `docs/` tree

| Measure | Before (`main`) | After this change |
|---|---:|---:|
| Tracked files under `docs/` | 201 | 16 source files |
| Source plans/specs/guidance/audit | 14, mixed at the root with generated output | 16, grouped under `agents/`, `specs/`, `plans/`, and `archive/`, plus `docs/README.md` |
| Generated or duplicated pkgdown files tracked under `docs/` | 187 | 0 |
| Generated-site destination | `_site/` existed, but an older site copy was also committed under `docs/` | `_site/` and GitHub Pages only; `docs/` legacy output paths are ignored |

### Resulting source tree

```text
ROADMAP.md                         authoritative package run sheet
docs/
├── README.md                      documentation authority map
├── agents/                        maintainer/agent workflow guidance
├── archive/                       completed and superseded audits
├── plans/                         per-issue historical execution evidence
└── specs/                         scientific/executable protocols
_site/                             generated pkgdown output (ignored)
```

## Cold-reader conclusion

A maintainer who has not read the implementation can now identify #61 as the
next task, see every open issue assigned to one lane, understand the complete
near-term AML Stage 1 gate, and distinguish scheduling, decisions, protocols,
history, current user documentation, and generated output without inferring
authority from file placement.

## Reproduction

```sh
gh issue list --repo drejom/landscapeR --state open --limit 200 \
  --json number > /tmp/open-issues.json
python3 scripts/check-roadmap.py --open-issues-json /tmp/open-issues.json
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
rm -rf _site
Rscript -e 'pkgdown::build_site()'
```

The before count is reproducible with:

```sh
git ls-tree -r --name-only main docs | wc -l
```
