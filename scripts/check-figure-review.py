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
OBVIOUSLY_QUALIFYING_PREFIXES = (
    ".github/", "data-raw/", "docs/agents/", "hooks/", "man/",
    "scripts/", "vignettes/",
)
OBVIOUSLY_QUALIFYING_FILES = {
    "DESCRIPTION", "NAMESPACE", "README.md", "_pkgdown.yml",
    "install-hooks.sh",
}
CURRENT_DOCS_REQUIRED_PREFIXES = ("data-raw/", "man/")
CURRENT_DOCS_REQUIRED_FILES = {"DESCRIPTION", "NAMESPACE"}
R_DEFINITION_PATTERN = re.compile(
    r"^\s*([A-Za-z.][A-Za-z0-9._]*)\s*<-\s*function\b",
    flags=re.MULTILINE,
)
R_S4_PATTERN = re.compile(
    r"\b(?:setGeneric|setClass|setClassUnion|setMethod)\s*\(\s*['\"]([^'\"]+)",
)
FULL_COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$", flags=re.IGNORECASE)
PROOF_MARKER = ".github/landing-proof/"


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
    without_comments = re.sub(r"<!--.*?-->", "", value, flags=re.DOTALL)
    normalized = re.sub(r"[`*_]", "", without_comments).strip().lower()
    starts_with_placeholder = any(
        normalized == token
        or re.match(rf"^{re.escape(token)}(?:\s|:|-|—)", normalized) is not None
        for token in PLACEHOLDERS if token
    )
    return not starts_with_placeholder and len(normalized) >= minimum


def fail(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def current_documentation_changed(files: list[str]) -> bool:
    return any(
        path in CURRENT_DOCUMENTATION_FILES
        or path.startswith(CURRENT_DOCUMENTATION_PREFIXES)
        for path in files
    )


def namespace_exports() -> set[str]:
    namespace = Path("NAMESPACE")
    if not namespace.is_file():
        return set()
    exports: set[str] = set()
    for _, contents in re.findall(
        r"^(export|exportMethods|exportClasses)\(([^)]+)\)",
        namespace.read_text(encoding="utf-8"),
        flags=re.MULTILINE,
    ):
        exports.add(contents.strip().strip("'\""))
    return exports


def public_or_scientific_r_changes(files: list[str]) -> list[str]:
    exports = namespace_exports()
    qualifying: list[str] = []
    for path_text in files:
        if not path_text.startswith("R/"):
            continue
        path = Path(path_text)
        if not path.is_file():
            continue
        source = path.read_text(encoding="utf-8")
        definitions = set(R_DEFINITION_PATTERN.findall(source))
        s4_symbols = set(R_S4_PATTERN.findall(source))
        if (
            "#' @export" in source
            or "register_strategy(" in source
            or bool(definitions & exports)
            or bool(s4_symbols & exports)
            or "setMethod(" in source
        ):
            qualifying.append(path_text)
    return qualifying


def validate_exemption(body: str, files: list[str]) -> int:
    category = field(body, "Exemption category")
    rationale = field(body, "Exemption rationale")
    if category not in ALLOWED_EXEMPTION_CATEGORIES:
        allowed = ", ".join(sorted(ALLOWED_EXEMPTION_CATEGORIES))
        return fail(f"Exemption category must be one of: {allowed}.")
    obviously_qualifying = [
        path for path in files
        if path in OBVIOUSLY_QUALIFYING_FILES
        or path.startswith(OBVIOUSLY_QUALIFYING_PREFIXES)
    ]
    obviously_qualifying.extend(public_or_scientific_r_changes(files))
    if obviously_qualifying:
        return fail(
            "An exemption cannot cover an obviously qualifying change: "
            + ", ".join(obviously_qualifying)
        )
    if not substantive(rationale, minimum=24):
        return fail("A substantive exemption rationale is required; generic N/A is invalid.")
    print(f"Visual landing proof exemption accepted ({category}).")
    return 0


def visual_review_has_artifact(body: str) -> bool:
    section_match = re.search(
        r"^## Visual review\s*$\n(.*?)(?=^##\s|\Z)",
        body,
        flags=re.MULTILINE | re.DOTALL,
    )
    if not section_match:
        return False
    section = section_match.group(1)
    has_image = re.search(r"!\[[^\]]+\]\([^)]+\)", section) is not None
    has_table = re.search(
        r"^\s*\|.+\|\s*$\n^\s*\|(?:\s*:?-+:?\s*\|)+\s*$",
        section,
        flags=re.MULTILINE,
    ) is not None
    has_rendered_output = re.search(r"```[^\n]*\n.+?```", section, re.DOTALL) is not None
    return has_image or has_table or has_rendered_output


def markdown_targets(body: str) -> list[str]:
    """Return normalized inline Markdown link and image targets."""
    return [
        target.strip().split()[0].strip("<>")
        for target in re.findall(r"!?\[[^\]]+\]\(([^)]+)\)", body)
    ]


def repository_proof_targets(body: str) -> list[tuple[str, Path, bool]]:
    """Return repository proof link targets paired with normalized local paths."""
    targets: list[tuple[str, Path, bool]] = []
    for match in re.finditer(r"(!)?\[[^\]]+\]\(([^)]+)\)", body):
        is_image = match.group(1) == "!"
        target = match.group(2).strip().split()[0].strip("<>")
        if PROOF_MARKER not in target:
            continue
        repository_path = PROOF_MARKER + target.split(PROOF_MARKER, maxsplit=1)[1]
        repository_path = repository_path.split("?", maxsplit=1)[0]
        repository_path = repository_path.split("#", maxsplit=1)[0]
        targets.append((target, Path(repository_path), is_image))
    return targets


def non_immutable_repository_proof_targets(
    body: str, expected_commit: str
) -> list[str]:
    """Return repository proof targets not pinned to the current PR-head SHA."""
    expected_pattern = re.compile(
        rf"/(?:blob/|tree/)?{re.escape(expected_commit)}/{re.escape(PROOF_MARKER)}",
        flags=re.IGNORECASE,
    )
    return [
        target for target, _, _ in repository_proof_targets(body)
        if expected_pattern.search(target) is None
    ]


def missing_repository_proof_paths(body: str) -> list[str]:
    """Return repository-hosted proof paths that do not exist in the checkout."""
    return [
        str(path) for _, path, _ in repository_proof_targets(body)
        if not path.exists()
    ]


def invalid_repository_proof_routes(
    body: str, expected_commit: str
) -> list[str]:
    """Return proof targets whose GitHub route does not match the path type."""
    raw_pattern = re.compile(
        rf"^https://raw\.githubusercontent\.com/[^/]+/[^/]+/"
        rf"{re.escape(expected_commit)}/{re.escape(PROOF_MARKER)}",
        flags=re.IGNORECASE,
    )
    blob_pattern = re.compile(
        rf"^https://github\.com/[^/]+/[^/]+/blob/"
        rf"{re.escape(expected_commit)}/{re.escape(PROOF_MARKER)}",
        flags=re.IGNORECASE,
    )
    tree_pattern = re.compile(
        rf"^https://github\.com/[^/]+/[^/]+/tree/"
        rf"{re.escape(expected_commit)}/{re.escape(PROOF_MARKER)}",
        flags=re.IGNORECASE,
    )
    invalid: list[str] = []
    for target, path, is_image in repository_proof_targets(body):
        if path.is_dir() and tree_pattern.search(target) is None:
            invalid.append(target)
        elif path.is_file():
            if is_image and raw_pattern.search(target) is None:
                invalid.append(target)
            elif not is_image and not (
                raw_pattern.search(target) or blob_pattern.search(target)
            ):
                invalid.append(target)
    return invalid


def validate_required_proof(
    body: str, files: list[str], expected_commit: str
) -> int:
    required_fields = (
        "Proof type",
        "Before",
        "After or representative output",
        "Cold-reader conclusion",
        "Reproduction",
        "Claim status",
        "Artifact",
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
    docs_required = bool(public_or_scientific_r_changes(files)) or any(
        path in CURRENT_DOCS_REQUIRED_FILES
        or path.startswith(CURRENT_DOCS_REQUIRED_PREFIXES)
        for path in files
    )
    if unaffected and docs_required:
        return fail(
            "A public API/documentation or prepared-data change requires current documentation."
        )
    if not visual_review_has_artifact(body):
        return fail(
            "The Visual review section must contain an inspectable artifact: "
            "a Markdown image, table, or fenced rendered output."
        )
    non_immutable_targets = non_immutable_repository_proof_targets(
        body, expected_commit
    )
    if non_immutable_targets:
        return fail(
            "Repository landing-proof links must use the current full PR-head "
            f"commit SHA ({expected_commit}); branch links break after deletion: "
            + ", ".join(non_immutable_targets)
        )
    missing_paths = missing_repository_proof_paths(body)
    if missing_paths:
        return fail(
            "Visual review references repository proof paths that do not exist: "
            + ", ".join(missing_paths)
        )
    invalid_routes = invalid_repository_proof_routes(body, expected_commit)
    if invalid_routes:
        return fail(
            "Repository proof URL type must match its committed artifact: use "
            "GitHub /tree/ for directories, /blob/ for text files, and raw "
            "URLs for image embeds: "
            + ", ".join(invalid_routes)
        )

    print("Visual landing proof packet accepted.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pr_body_file", type=Path, help="File containing the PR body")
    parser.add_argument(
        "--expected-commit",
        help="Full immutable PR-head commit SHA required in repository proof links",
    )
    args = parser.parse_args()

    if not args.pr_body_file.is_file():
        return fail(f"PR body file not found: {args.pr_body_file}")

    body = args.pr_body_file.read_text(encoding="utf-8")
    if re.search(r"^## Visual landing proof\s*$", body, re.MULTILINE) is None:
        return fail("A `## Visual landing proof` heading is required.")
    proof_required = checked(body, "Proof required")
    exempt = checked(body, "Exempt")
    if proof_required == exempt:
        return fail("Select exactly one visual landing-proof classification: Proof required or Exempt.")

    try:
        files = changed_files()
    except RuntimeError as error:
        return fail(str(error))

    expected_commit = args.expected_commit
    if expected_commit is None:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"], capture_output=True, text=True
        )
        if result.returncode != 0:
            return fail("cannot determine the current commit for proof-link validation")
        expected_commit = result.stdout.strip()
    if FULL_COMMIT_PATTERN.fullmatch(expected_commit) is None:
        return fail("Expected proof-link commit must be a full 40-character SHA.")

    if exempt:
        return validate_exemption(body, files)
    return validate_required_proof(body, files, expected_commit.lower())


if __name__ == "__main__":
    raise SystemExit(main())
