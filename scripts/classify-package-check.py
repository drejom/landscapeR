#!/usr/bin/env python3
"""Select the full package check unless every changed path is documentation-only."""

import argparse
import sys


MARKDOWN_ROOTS = ("context/", "decisions/", "docs/")
LANDING_PROOF_EXTENSIONS = {".csv", ".gif", ".jpeg", ".jpg", ".md", ".png", ".svg", ".tsv", ".txt"}
ISSUE_TEMPLATE_EXTENSIONS = {".md", ".yaml", ".yml"}
DOC_FILES = {"CODE_OF_CONDUCT", "LICENSE", "LICENSE.md", "NEWS.md"}


def normalize(path: str) -> str:
    path = path.strip().replace("\\", "/")
    while path.startswith("./"):
        path = path[2:]
    return path


def documentation_only(path: str) -> bool:
    if not path:
        return True
    suffix = "." + path.rsplit(".", maxsplit=1)[1].lower() if "." in path.rsplit("/", maxsplit=1)[-1] else ""
    if path in DOC_FILES or ("/" not in path and suffix == ".md"):
        return True
    if path.startswith(MARKDOWN_ROOTS):
        return suffix == ".md"
    if path.startswith(".github/landing-proof/"):
        return suffix in LANDING_PROOF_EXTENSIONS
    if path.startswith(".github/ISSUE_TEMPLATE/"):
        return suffix in ISSUE_TEMPLATE_EXTENSIONS
    return False


def classify(paths: list[str], force_full: bool = False) -> str:
    normalized = []
    for raw_path in paths:
        path = normalize(raw_path)
        if path:
            normalized.append(path)
    if force_full or not normalized:
        return "full"
    return "docs-only" if all(documentation_only(path) for path in normalized) else "full"


def main() -> int:
    parser = argparse.ArgumentParser()
    input_group = parser.add_mutually_exclusive_group()
    input_group.add_argument("--stdin", action="store_true")
    input_group.add_argument("--stdin-zero", action="store_true")
    parser.add_argument("--force-full", action="store_true")
    parser.add_argument("--github-output")
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args()

    paths = list(args.paths)
    if args.stdin or args.stdin_zero:
        separator = "\0" if args.stdin_zero else "\n"
        paths.extend(sys.stdin.read().split(separator))

    scope = classify(paths, force_full=args.force_full)
    if args.github_output:
        with open(args.github_output, "a", encoding="utf-8") as output:
            output.write(f"run_full={'true' if scope == 'full' else 'false'}\n")
            output.write(f"scope={scope}\n")
    print(scope)
    return 0


if __name__ == "__main__":
    sys.exit(main())
