#!/usr/bin/env python3
"""Validate the committed issue #226 public-plot contact-sheet contract."""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path


def _namespace_plot_symbols(namespace: Path) -> set[str]:
    text = namespace.read_text(encoding="utf-8")
    exported = set(re.findall(r"^export\((plot_[^)]+)\)$", text, re.MULTILINE))
    s3_methods = set(
        f"plot.{class_name}"
        for class_name in re.findall(
            r"^S3method\(plot,([^)]+)\)$", text, re.MULTILINE
        )
    )
    return exported | s3_methods


def _inventory(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    required = {
        "id", "included", "function_name", "figure", "caption",
        "exclusion_reason",
    }
    if not rows or not required.issubset(rows[0]):
        raise ValueError("issue #226 inventory has an incomplete schema")
    return rows


def check_contact_sheet_contract(repo_root: Path) -> list[str]:
    proof_root = repo_root / ".github" / "landing-proof" / "issue-226"
    inventory_path = proof_root / "public-plot-inventory.tsv"
    if not inventory_path.is_file():
        raise ValueError(f"missing contact-sheet inventory: {inventory_path}")

    rows = _inventory(inventory_path)
    symbols = {row["function_name"] for row in rows}
    namespace_symbols = _namespace_plot_symbols(repo_root / "NAMESPACE")
    if symbols != namespace_symbols:
        missing = sorted(namespace_symbols - symbols)
        unexpected = sorted(symbols - namespace_symbols)
        raise ValueError(
            "public plot inventory is out of sync with NAMESPACE: "
            f"missing={missing}; unexpected={unexpected}"
        )

    included = [row for row in rows if row["included"] == "TRUE"]
    excluded = [row for row in rows if row["included"] == "FALSE"]
    if len(included) != 17 or len(excluded) != 7:
        raise ValueError(
            "issue #226 inventory must retain 17 included and 7 excluded plotters"
        )

    script_text = (
        repo_root / "scripts" / "render-issue-226-contact-sheet.R"
    ).read_text(encoding="utf-8")
    absent_from_renderer = sorted(
        symbol for symbol in symbols
        if not re.search(
            rf"(?<![A-Za-z0-9_.]){re.escape(symbol)}(?![A-Za-z0-9_.])",
            script_text,
        )
    )
    if absent_from_renderer:
        raise ValueError(
            "contact-sheet renderer does not mention inventory symbols: "
            f"{absent_from_renderer}"
        )

    for row in included:
        for column in ("figure", "caption"):
            artifact = proof_root / row[column]
            if not artifact.is_file():
                raise ValueError(f"missing included {column}: {artifact}")
        if row["exclusion_reason"]:
            raise ValueError(f"included plot has an exclusion reason: {row['id']}")
    for row in excluded:
        if row["figure"] or row["caption"] or not row["exclusion_reason"]:
            raise ValueError(
                f"excluded plot has invalid retained-artifact fields: {row['id']}"
            )

    return [
        "validated "
        f"{len(included)} included and {len(excluded)} excluded public plotters",
        "validated NAMESPACE parity, renderer coverage, and retained artifacts",
    ]


def main(argv: list[str] | None = None) -> int:
    root = Path(argv[0]).resolve() if argv else Path(__file__).resolve().parents[1]
    try:
        for message in check_contact_sheet_contract(root):
            print(f"issue #226 contact-sheet contract: {message}")
    except (OSError, ValueError) as error:
        print(f"issue #226 contact-sheet contract failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
