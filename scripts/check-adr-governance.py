#!/usr/bin/env python3
"""Validate active ADR identity, status, and resolution metadata."""

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path


ADR_FILE = re.compile(r"^(\d{4})-.+\.md$")
STATUS = re.compile(r"^\*\*Status:\*\*\s*(.+?)\s*$")
RESOLUTION = re.compile(r"^\*\*Resolution issue:\*\*\s*#(\d+)\s*$")
EXACT_STATUSES = {"proposed", "provisional-accepted", "accepted", "reopened", "rejected"}
RESOLUTION_STATUSES = {"provisional-accepted", "reopened"}


def validate(decisions_dir: Path) -> list[str]:
    errors: list[str] = []
    by_number: dict[str, list[Path]] = defaultdict(list)

    for path in sorted(decisions_dir.iterdir()):
        match = ADR_FILE.match(path.name)
        if not path.is_file() or not match or path.name == "0000-template.md":
            continue
        by_number[match.group(1)].append(path)

        lines = path.read_text(encoding="utf-8").splitlines()
        declarations = [line for line in lines if line.lstrip().startswith("**Status")]
        canonical = [STATUS.fullmatch(line.strip()) for line in declarations]
        canonical = [match for match in canonical if match]
        if len(declarations) != 1 or len(canonical) != 1:
            errors.append(f"{path}: expected exactly one canonical **Status:** declaration")
            continue

        status = canonical[0].group(1)
        valid_status = status in EXACT_STATUSES or re.fullmatch(r"superseded-by \d{4}", status)
        if not valid_status:
            errors.append(f"{path}: invalid ADR status {status!r}")

        resolutions = [RESOLUTION.fullmatch(line.strip()) for line in lines]
        resolutions = [match for match in resolutions if match]
        if status in RESOLUTION_STATUSES and len(resolutions) != 1:
            errors.append(f"{path}: status {status!r} requires exactly one **Resolution issue:** #NN")

    for number, paths in sorted(by_number.items()):
        if len(paths) > 1:
            names = ", ".join(path.name for path in paths)
            errors.append(f"duplicate active ADR number {number}: {names}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--decisions-dir", type=Path, default=Path("decisions"))
    args = parser.parse_args()
    errors = validate(args.decisions_dir)
    if errors:
        print("ADR governance violations:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("ADR governance: active numbers, statuses, and resolution issues are valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
