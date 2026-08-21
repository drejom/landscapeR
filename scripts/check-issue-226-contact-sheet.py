#!/usr/bin/env python3
"""Validate the committed issue #226 public-plot contact-sheet contract."""

from __future__ import annotations

import csv
import re
import struct
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


def _tile_labels(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    required = {"panel", "id", "label", "characters"}
    if not rows or not required.issubset(rows[0]):
        raise ValueError("contact-sheet tile-label contract has an incomplete schema")
    for row in rows:
        if not row["label"].strip() or len(row["label"]) > 25:
            raise ValueError(f"contact-sheet tile label exceeds 25 characters: {row['id']}")
        if row["characters"] != str(len(row["label"])):
            raise ValueError(f"contact-sheet tile-label character count is wrong: {row['id']}")
    return rows


def _png_dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"not a valid PNG: {path}")
    return struct.unpack(">II", data[16:24])


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
    helper_path = repo_root / "R" / "13q-contact-sheet.R"
    if not helper_path.is_file():
        raise ValueError(f"missing contact-sheet tile helper: {helper_path}")
    script_text += "\n" + helper_path.read_text(encoding="utf-8")
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

    native_sheet = proof_root / "public-plot-contact-sheet.png"
    reduced_sheet = proof_root / "public-plot-contact-sheet-reduced.png"
    label_path = proof_root / "public-plot-contact-sheet-labels.tsv"
    if not label_path.is_file():
        raise ValueError(f"missing contact-sheet tile-label contract: {label_path}")
    labels = _tile_labels(label_path)
    if [row["id"] for row in labels] != [row["id"] for row in included]:
        raise ValueError("contact-sheet tile labels are out of inventory order")
    expected_panels = [chr(ord("A") + index) for index in range(len(labels))]
    if [row["panel"] for row in labels] != expected_panels:
        raise ValueError("contact-sheet tile labels have invalid panel order")
    for sheet in (native_sheet, reduced_sheet):
        if not sheet.is_file():
            raise ValueError(f"missing contact-sheet QA artifact: {sheet}")
    native_width, native_height = _png_dimensions(native_sheet)
    reduced_width, reduced_height = _png_dimensions(reduced_sheet)
    if reduced_width >= native_width or reduced_height >= native_height:
        raise ValueError(
            "reduced contact sheet must have strictly smaller pixel dimensions "
            f"than native ({native_width}x{native_height} vs "
            f"{reduced_width}x{reduced_height})"
        )
    if "contact_sheet_tile" not in script_text or "subtitle = NULL" not in script_text:
        raise ValueError("renderer does not enforce concise, subtitle-free tile labels")
    if "public-plot-contact-sheet-reduced.png" not in script_text:
        raise ValueError("renderer does not generate the reduced contact-sheet QA artifact")
    if 'reference_level = "low"' not in script_text or 'focal_level = "high"' not in script_text:
        raise ValueError(
            "renderer does not declare the binary reference/focal palette for Stage 1/2 proofs"
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
        "validated native/reduced dimensions and bounded tile-label contract; manual visual QA remains required",
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
