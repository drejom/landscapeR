# Issue #61 visual landing proof

**Claim status:** schema/API implementation proof only. This change does not
accept a scientific strategy or make a biological claim.

## Before and after

| Behavior | v1 | v2 |
|---|---|---|
| Target and component | Mutually exclusive `target_field` / `manual_component` | Target is mandatory and retained when `selected_component` is added |
| Target direction | Not represented | Binary reference/comparison, ordered levels, or continuous direction |
| Proposal identity | Not represented | Ranked proposal SHA-256 digest retained in proposal/confirmed states |
| Human decision | Encoded ambiguously as “manual” component | Explicit `accepted` / `overridden` decision plus non-empty rationale |
| Stage 2 boundary | Any manual component could proceed | Requires a confirmed v2 specification and an in-bounds selected component |
| Legacy behavior | Target or component information was necessarily absent | Migration requires missing intent/provenance explicitly; nothing is fabricated or silently dropped |

## Representative lifecycle

The target declaration remains identical across every row; later states only
add proposal and confirmation information.

| lifecycle | target field | target direction | proposal digest | selected component | decision |
|---|---|---|---|---:|---|
| `draft` | `condition` | `control → disease` | absent | — | absent |
| `proposal` | `condition` | `control → disease` | retained | — | absent |
| `confirmed` | `condition` | `control → disease` | retained | 2 | `accepted` + rationale |

## Explicit v1 migration

| Serialized v1 artifact | Recoverable | Required explicit input | v2 result |
|---|---|---|---|
| Target-only | target field, nuisance fields, claim intent | target type and contrast/order/direction | draft, or proposal when a proposal digest is supplied |
| Component-only | selected component, nuisance/orientation fields, claim intent | target field, target direction, proposal digest, accept/override decision, rationale | confirmed |

Both migrations record the exact v1 canonical payload digest in
`migration_source_digest`. Missing required declarations fail rather than
producing a legacy/null fallback.

## Reproduction

```sh
Rscript -e 'devtools::test(filter = "analysis-specification")'
Rscript -e 'devtools::test()'
Rscript -e 'pkgdown::build_site()'
```

The real serialized v1 fixture exercised by the migration tests is
`tests/testthat/fixtures/analysis-specification-v1.rds`.
