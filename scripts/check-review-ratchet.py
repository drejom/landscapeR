#!/usr/bin/env python3
"""Validate the incident-backed review ratchet and optional PR disposition."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIRED_SECTIONS = (
    "Gate sequence",
    "Never-touch list",
    "Earned defect checklist",
    "Verify, never assume",
    "Maintenance duties",
)
DISPOSITIONS = ("Unchanged", "Updated", "Corrected", "Deduplicated", "Graduated")
PLACEHOLDERS = {"", "n/a", "na", "none", "tbd", "todo", "placeholder"}


def fail(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def substantive(value: str | None) -> bool:
    if value is None:
        return False
    value = re.sub(r"<!--.*?-->", "", value, flags=re.DOTALL)
    normalized = re.sub(r"[`*_]", "", value).strip().lower()
    return len(normalized) >= 24 and normalized not in PLACEHOLDERS


def section(text: str, heading: str) -> str | None:
    match = re.search(
        rf"^## {re.escape(heading)}\s*$\n(.*?)(?=^##\s|\Z)",
        text,
        flags=re.MULTILINE | re.DOTALL,
    )
    return match.group(1) if match else None


def validate_document(path: Path) -> list[str]:
    if not path.is_file():
        return [f"review ratchet not found: {path}"]
    text = path.read_text(encoding="utf-8")
    errors: list[str] = []
    if len(text.splitlines()) > 150:
        errors.append("review ratchet exceeds the 150-line readability cap")
    for required_section in REQUIRED_SECTIONS:
        heading_count = len(re.findall(
            rf"^## {re.escape(required_section)}\s*$", text, re.MULTILINE
        ))
        if heading_count == 0:
            errors.append(f"missing required section: {required_section}")
        elif heading_count > 1:
            errors.append(f"duplicate required section: {required_section}")

    earned = section(text, "Earned defect checklist") or ""
    headings = re.findall(r"^### (.+)$", earned, re.MULTILINE)
    malformed = [
        heading for heading in headings
        if re.fullmatch(r"RR-\d{3} — .+", heading) is None
    ]
    if malformed:
        errors.append("malformed earned entry headings: " + ", ".join(malformed))
    entries = list(re.finditer(r"^### (RR-\d{3}) — .+$", earned, re.MULTILINE))
    identifiers = [entry.group(1) for entry in entries]
    duplicates = sorted({item for item in identifiers if identifiers.count(item) > 1})
    if duplicates:
        errors.append("duplicate review-ratchet identifiers: " + ", ".join(duplicates))
    for index, entry in enumerate(entries):
        end = entries[index + 1].start() if index + 1 < len(entries) else len(earned)
        block = earned[entry.end():end]
        incident = re.search(r"^\*\*Incident:\*\*\s*(.+)$", block, re.MULTILINE)
        if incident is None or re.search(r"(?:/issues/|/pull/|#[0-9]+)", incident.group(1)) is None:
            errors.append(f"{entry.group(1)} lacks a concrete repository incident")
    return errors


def validate_pr_body(path: Path) -> list[str]:
    if not path.is_file():
        return [f"pull-request body not found: {path}"]
    text = path.read_text(encoding="utf-8")
    errors: list[str] = []
    ratchet_heading_count = len(re.findall(
        r"^## Review ratchet\s*$", text, re.MULTILINE
    ))
    ratchet = section(text, "Review ratchet")
    if ratchet_heading_count == 0:
        errors.append("pull request is missing the Review ratchet section")
        ratchet = ""
    elif ratchet_heading_count > 1:
        errors.append("pull request contains duplicate Review ratchet sections")
    selected = []
    for disposition in DISPOSITIONS:
        match = re.search(
            rf"^- \[([ xX])\] {re.escape(disposition)}\s*$", ratchet, re.MULTILINE
        )
        if match and match.group(1).lower() == "x":
            selected.append(disposition)
    if len(selected) != 1:
        errors.append("select exactly one review-ratchet disposition")
    rationale = re.search(
        r"^\*\*Ratchet rationale:\*\*\s*(.*?)\s*$", ratchet, re.MULTILINE
    )
    if not substantive(rationale.group(1) if rationale else None):
        errors.append("review-ratchet disposition requires a substantive rationale")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--document", type=Path, default=Path("docs/agents/review-ratchet.md")
    )
    parser.add_argument("--pr-body", type=Path)
    args = parser.parse_args()

    errors = validate_document(args.document)
    if args.pr_body is not None:
        errors.extend(validate_pr_body(args.pr_body))
    if errors:
        return fail("; ".join(errors))
    print("Review ratchet verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
