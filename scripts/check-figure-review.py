#!/usr/bin/env python3
"""Fail on PRs that modify vignettes/ without a Figure review section in the PR body.

Usage: python3 scripts/check-figure-review.py <pr_body_file>

The PR body file should contain the full PR description text. Exits 0 when no
vignette was changed or when a Figure review section is present and filled in.
Exits 1 when a vignette was changed but the Figure review section is absent or
contains only the template placeholder comment.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path


def vignettes_changed() -> bool:
    """Return True when the current diff touches any file under vignettes/.

    Tries to diff against origin/main, then main, then HEAD~1 (for local use).
    Falls back to True (fail-safe) if none of these refs are available, which
    can happen in shallow clones where the target ref is not fetched.
    """
    for target in ["origin/main", "main", "HEAD~1"]:
        result = subprocess.run(
            ["git", "diff", "--name-only", target, "HEAD"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            changed = result.stdout.splitlines()
            return any(f.startswith("vignettes/") for f in changed)
    # Can't determine changed files — fail safe: assume yes
    return True


def has_figure_review(body: str) -> bool:
    """Return True when the PR body contains a filled Figure review section."""
    # Section must exist
    if "## Figures" not in body and "**Figure review**" not in body:
        return False
    # Must not consist only of the template placeholder comment
    section_match = re.search(
        r"\*\*Figure review\*\*.*?(?=\n##|\Z)", body, re.DOTALL
    )
    if not section_match:
        return False
    section = section_match.group(0)
    # Strip HTML comments
    stripped = re.sub(r"<!--.*?-->", "", section, flags=re.DOTALL).strip()
    # Require at least one non-empty line after the header (actual content)
    content_lines = [l.strip() for l in stripped.splitlines()
                     if l.strip() and not l.strip().startswith("**Figure review**")]
    return len(content_lines) > 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pr_body_file", type=Path,
                        help="File containing the PR body text")
    args = parser.parse_args()

    if not args.pr_body_file.is_file():
        print(f"PR body file not found: {args.pr_body_file}", file=sys.stderr)
        return 1

    body = args.pr_body_file.read_text(encoding="utf-8")

    if not vignettes_changed():
        print("No vignette changes detected — figure review not required.")
        return 0

    if has_figure_review(body):
        print("Figure review section found and filled in.")
        return 0

    print(
        "ERROR: This PR modifies vignettes/ but the PR body does not contain a "
        "filled '**Figure review**' section.\n"
        "Please screenshot each rendered figure, visually inspect it, and write "
        "a one-sentence interpretation per figure in the PR description.\n"
        "See .github/pull_request_template.md for the required format.",
        file=sys.stderr
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
