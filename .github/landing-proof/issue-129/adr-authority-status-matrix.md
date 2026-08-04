# ADR authority and status matrix

| Record | Before | After | Resolution authority |
|---|---|---|---|
| ADR 0001 | compound provisional/reopened prose | `reopened` | issue #49 |
| ADR 0002 | `provisional-accepted`, no named exit | `provisional-accepted` | issue #51 |
| ADR 0004 | `proposed` header plus an inline `accepted` declaration | `accepted` | not required |
| ADR 0010 | `provisional-accepted`, no named exit | `provisional-accepted` | issue #5 |
| ADR 0015 | undocumented `provisional` status | `provisional-accepted` | issue #49 |
| ADR 0020 | two active files with different authority and status | one accepted active ADR; earlier draft archived | `decisions/0020-stage1-component-interpretation-strategy.md` |

The checker makes the after-state executable: active numbers must be unique,
statuses must use the documented vocabulary, contradictory declarations fail,
and every provisional or reopened decision names its resolution issue.
