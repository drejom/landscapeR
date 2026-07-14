#!/usr/bin/env python3
"""Enforce the pull-request visual landing-proof policy.

Every PR must declare exactly one of:

* proof required, with a complete proof packet and documentation disposition; or
* exempt, with an allowed category and substantive rationale.

The checker observes the same public seam in CI and tests: PR body + Git diff.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


ALLOWED_EXEMPTION_CATEGORIES = {"internal-only", "research/decision-only"}
PLACEHOLDERS = {
    "", "-", "n/a", "na", "none", "not applicable", "tbd", "todo",
    "placeholder", "same as above",
}
CURRENT_DOCUMENTATION_PREFIXES = ("vignettes/",)
CURRENT_DOCUMENTATION_FILES = {"README.md"}
OBVIOUSLY_PUBLIC_PREFIXES = ("data-raw/", "vignettes/")
OBVIOUSLY_PUBLIC_FILES = {"DESCRIPTION", "NAMESPACE", "README.md"}


def changed_files() -> list[str]:
    """Return files changed from the first available merge-base candidate."""
    for target in ["origin/main", "main", "HEAD~1"]:
        result = subprocess.run(
            ["git", "diff", "--name-only", f"{target}...HEAD"],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return [line for line in result.stdout.splitlines() if line]
    raise RuntimeError("cannot determine changed files from origin/main, main, or HEAD~1")


def checked(body: str, label: str) -> bool:
    pattern = rf"^- \[([ xX])\] {re.escape(label)}\s*$"
    match = re.search(pattern, body, flags=re.MULTILINE)
    return bool(match and match.group(1).lower() == "x")


def field(body: str, label: str) -> str | None:
    pattern = rf"^\*\*{re.escape(label)}:\*\*[ \t]*(.*?)[ \t]*$"
    match = re.search(pattern, body, flags=re.MULTILINE)
    return match.group(1).strip() if match else None


def substantive(value: str | None, minimum: int = 12) -> bool:
    if value is None:
        return False
    normalized = re.sub(r"[`*_]", "", value).strip().lower()
    return normalized not in PLACEHOLDERS and len(normalized) >= minimum


def fail(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def current_documentation_changed(files: list[str]) -> bool:
    return any(
        path in CURRENT_DOCUMENTATION_FILES
        or path.startswith(CURRENT_DOCUMENTATION_PREFIXES)
        for path in files
    )


def validate_exemption(body: str, files: list[str]) -> int:
    category = field(body, "Exemption category")
    rationale = field(body, "Exemption rationale")
    if category not in ALLOWED_EXEMPTION_CATEGORIES:
        allowed = ", ".join(sorted(ALLOWED_EXEMPTION_CATEGORIES))
        return fail(f"Exemption category must be one of: {allowed}.")
    obvious_public = [
        path for path in files
        if path in OBVIOUSLY_PUBLIC_FILES
        or path.startswith(OBVIOUSLY_PUBLIC_PREFIXES)
    ]
    if obvious_public:
        return fail(
            "An exemption cannot cover an obviously public change: "
            + ", ".join(obvious_public)
        )
    if not substantive(rationale, minimum=24):
        return fail("A substantive exemption rationale is required; generic N/A is invalid.")
    print(f"Visual landing proof exemption accepted ({category}).")
    return 0


def validate_required_proof(body: str, files: list[str]) -> int:
    required_fields = (
        "Proof type",
        "Before",
        "After or representative output",
        "Cold-reader conclusion",
        "Reproduction",
        "Claim status",
    )
    for label in required_fields:
        if not substantive(field(body, label)):
            return fail(f"{label} must contain substantive visual landing-proof content.")

    proof_type = field(body, "Proof type")
    if proof_type not in {"before-after", "new-capability", "representative-output"}:
        return fail(
            "Proof type must be before-after, new-capability, or representative-output."
        )

    updated = checked(body, "Updated")
    unaffected = checked(body, "Unaffected")
    if updated == unaffected:
        return fail("Select exactly one current-documentation disposition: Updated or Unaffected.")

    documentation = field(body, "Documentation reference or rationale")
    if not substantive(documentation, minimum=20):
        return fail("Documentation reference or rationale must be substantive.")
    if updated and not current_documentation_changed(files):
        return fail(
            "Current documentation is declared updated, but no README or vignette change "
            "exists in the current documentation diff."
        )

    print("Visual landing proof packet accepted.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pr_body_file", type=Path, help="File containing the PR body")
    args = parser.parse_args()

    if not args.pr_body_file.is_file():
        return fail(f"PR body file not found: {args.pr_body_file}")

    body = args.pr_body_file.read_text(encoding="utf-8")
    proof_required = checked(body, "Proof required")
    exempt = checked(body, "Exempt")
    if proof_required == exempt:
        return fail("Select exactly one visual landing-proof classification: Proof required or Exempt.")

    try:
        files = changed_files()
    except RuntimeError as error:
        return fail(str(error))

    if exempt:
        return validate_exemption(body, files)
    return validate_required_proof(body, files)


if __name__ == "__main__":
    raise SystemExit(main())
