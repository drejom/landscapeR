#!/usr/bin/env python3
"""
Enforce ADR coverage for registered strategies.

Every call to register_strategy("Contract", "name", ...) in R/ must have a
backing ADR in decisions/ whose body mentions the strategy name.

This prevents strategies from appearing in the registry without a documented
rationale — the key discipline from CLAUDE.md: "every non-trivial algorithm or
dependency choice needs an ADR before code is written."

Exit codes:
  0  All registered strategies are covered
  1  One or more strategies have no backing ADR
"""

import re
import sys
from pathlib import Path

R_DIR       = Path("R")
DECISIONS   = Path("decisions")

# Strategies that are intentionally undocumented because they are debug
# baselines or internal helpers (add with justification).
EXEMPT = {
    "hogsvd_prereduced",   # debug baseline for hogsvd_averaged; covered by ADR 0001
}


def registered_strategies() -> list[tuple[str, str, str]]:
    """Return (contract, name, file) for every register_strategy() call in R/."""
    results = []
    pat = re.compile(r'register_strategy\(\s*"([^"]+)"\s*,\s*"([^"]+)"')
    for path in sorted(R_DIR.glob("*.R")):
        for m in pat.finditer(path.read_text(encoding="utf-8")):
            results.append((m.group(1), m.group(2), str(path)))
    return results


def adr_texts() -> list[str]:
    """Return the concatenated text of all ADR files."""
    texts = []
    for path in sorted(DECISIONS.glob("*.md")):
        if path.name == "0000-template.md":
            continue
        texts.append(path.read_text(encoding="utf-8"))
    return texts


def main() -> int:
    strategies = registered_strategies()
    if not strategies:
        print("✓ No register_strategy() calls found — nothing to check.")
        return 0

    adrs = adr_texts()
    violations = []

    for contract, name, src_file in strategies:
        if name in EXEMPT:
            continue
        covered = any(name in adr for adr in adrs)
        if not covered:
            violations.append(
                f'No ADR covers strategy "{contract}:{name}" '
                f'(registered in {src_file}). '
                f'Add a decisions/NNNN-*.md that mentions "{name}".'
            )

    if violations:
        print("✗ ADR coverage violations:\n")
        for v in violations:
            print(f"  → {v}")
        print(f"\n{len(violations)} violation(s) found.")
        return 1

    names = [f"{c}:{n}" for c, n, _ in strategies if n not in EXEMPT]
    print(f"✓ ADR coverage: {len(names)} strategy/ies covered — {', '.join(names)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
