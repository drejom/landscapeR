# Domain Docs

## Layout

This repo uses a **multi-context** layout. `CONTEXT-MAP.md` at the root points to per-context files under `context/`. Shared architectural decisions live in `decisions/`. `ROADMAP.md` alone owns scheduling.

```
/
├── ROADMAP.md              ← authoritative scope, sequence, gates, next task
├── CONTEXT-MAP.md          ← index of all bounded contexts
├── context/                ← per-context CONTEXT.md files
├── decisions/              ← shared ADRs (all stages)
│   ├── README.md           ← ADR workflow — read before making algorithm choices
│   └── 0001-*.md ... 0005-*.md
└── UBIQUITOUS_LANGUAGE.md  ← canonical domain glossary
```

## Reading rules for agents

- Read `ROADMAP.md` before selecting work; issues, contexts, ADRs, plans, and archives do not independently set priority.
- Load `CONTEXT-MAP.md` to find the relevant context file.
- Read `UBIQUITOUS_LANGUAGE.md` for canonical term definitions before writing any issue body, brief, or comment.
- Read `decisions/README.md` before recommending any algorithm or dependency choice — ADRs are mandatory before code.
- ADR status meanings: `accepted` = settled, `provisional-accepted` = in use but thresholds TBD, `provisional` = under evaluation.

## Key domain terms

- **StateTransitionData** — the single container flowing between all stages (MAE subclass)
- **Stage 0** — synthetic control ladder (load-bearing validation)
- **Stage 1** — comparative decomposition (GSVD / HO-GSVD)
- **Stage 2** — quasi-potential dynamics (log-density inversion)
- **primary_2018** — 132-observation source-paper training cohort; primary discovery basis for the exploratory landscapeR AML workflow
- **supp_2016** — 101-observation source-paper validation cohort 1; batch/time-confounded secondary projection stress test
