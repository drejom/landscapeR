#!/usr/bin/env python3
"""Validate the authoritative landscapeR roadmap and documentation links."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote


ISSUE_MAP_START = "<!-- issue-map:start -->"
ISSUE_MAP_END = "<!-- issue-map:end -->"
ISSUE_ROW = re.compile(
    r"^\| \[#(?P<number>\d+)\]\(https://github\.com/drejom/landscapeR/issues/\d+\) "
    r"\| (?P<lane>[^|]+) \| (?P<state>[^|]+) \|$",
    flags=re.MULTILINE,
)
NEXT_TASK = re.compile(
    r"^\*\*Next task[^\n]*:\*\*\s+\*\*#(?P<number>\d+)\b",
    flags=re.MULTILINE,
)
LOCAL_LINK = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]*)\)")
ALLOWED_STATE_PREFIXES = ("active", "queued", "conditional", "parked", "complete")
ALLOWED_DOCS_AREAS = {
    "agents": {".md"},
    "archive": {".md"},
    "plans": {".md"},
    "research": {".md"},
    "reviews": {".md", ".json"},
    "specs": {".md"},
}


def fail(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def read_text(path: Path, label: str) -> str:
    if not path.is_file():
        raise ValueError(f"{label} not found: {path}")
    return path.read_text(encoding="utf-8")


def issue_rows(roadmap: str) -> dict[int, str]:
    if roadmap.count(ISSUE_MAP_START) != 1 or roadmap.count(ISSUE_MAP_END) != 1:
        raise ValueError("roadmap must contain exactly one canonical issue-map block")
    block = roadmap.split(ISSUE_MAP_START, 1)[1].split(ISSUE_MAP_END, 1)[0]
    rows: dict[int, str] = {}
    for match in ISSUE_ROW.finditer(block):
        number = int(match.group("number"))
        url_number = int(re.search(r"/issues/(\d+)", match.group(0)).group(1))
        if number != url_number:
            raise ValueError(f"issue row #{number} links to #{url_number}")
        if number in rows:
            raise ValueError(f"duplicate issue row: #{number}")
        state = match.group("state").strip().lower()
        if not state.startswith(ALLOWED_STATE_PREFIXES):
            raise ValueError(f"issue #{number} has invalid roadmap state: {state}")
        rows[number] = state
    if not rows:
        raise ValueError("canonical issue-map contains no issue rows")
    return rows


def check_open_issues(rows: dict[int, str], json_path: Path) -> None:
    payload = json.loads(read_text(json_path, "open-issues JSON"))
    open_numbers = {int(item["number"]) for item in payload}
    missing = sorted(open_numbers - rows.keys())
    if missing:
        rendered = ", ".join(f"#{number}" for number in missing)
        raise ValueError(f"open issues missing from canonical roadmap map: {rendered}")
    stale = sorted(
        number for number in rows.keys() - open_numbers
        if not rows[number].startswith("complete")
    )
    if stale:
        rendered = ", ".join(f"#{number}" for number in stale)
        raise ValueError(
            "non-open roadmap issues must be marked complete or removed: " + rendered
        )


def is_hidden_path(path: Path, root: Path) -> bool:
    return any(part.startswith(".") for part in path.relative_to(root).parts)


def check_docs_layout(docs_root: Path) -> None:
    for path in docs_root.rglob("*"):
        if not path.is_file() or is_hidden_path(path, docs_root):
            continue
        relative = path.relative_to(docs_root)
        if relative == Path("README.md"):
            continue
        area = relative.parts[0]
        if area not in ALLOWED_DOCS_AREAS or path.suffix not in ALLOWED_DOCS_AREAS[area]:
            raise ValueError(
                f"generated or uncategorized file under source docs: {path}"
            )


def check_local_links(path: Path, text: str, repo_root: Path) -> None:
    for raw_target in LOCAL_LINK.findall(text):
        raw_target = raw_target.strip()
        if not raw_target:
            raise ValueError(f"empty Markdown link in {path}")
        if raw_target.startswith("<") and raw_target.endswith(">"):
            target = raw_target[1:-1]
        else:
            target = raw_target.split(maxsplit=1)[0]
        if target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        target = unquote(target.split("#", 1)[0])
        if not target:
            continue
        target_path = Path(target)
        if target_path.is_absolute():
            raise ValueError(f"local link points outside repository in {path}: {raw_target}")
        resolved = (path.parent / target_path).resolve()
        try:
            resolved.relative_to(repo_root)
        except ValueError as error:
            raise ValueError(
                f"local link points outside repository in {path}: {raw_target}"
            ) from error
        if not resolved.exists():
            raise ValueError(f"broken local link in {path}: {raw_target}")


def validate(
    roadmap_path: Path,
    docs_index_path: Path,
    docs_root: Path,
    open_issues_path: Path | None,
) -> None:
    roadmap = read_text(roadmap_path, "roadmap")
    docs_index = read_text(docs_index_path, "documentation index")

    if not roadmap.startswith("# landscapeR roadmap"):
        raise ValueError("roadmap must start with `# landscapeR roadmap`")
    if roadmap.count("**Scheduling authority:**") != 1:
        raise ValueError("roadmap must contain exactly one `Scheduling authority` declaration")
    if "# Active milestone" not in roadmap or "# Change control" not in roadmap:
        raise ValueError("roadmap must define Active milestone and Change control sections")

    next_tasks = [int(match.group("number")) for match in NEXT_TASK.finditer(roadmap)]
    if len(next_tasks) != 1:
        raise ValueError("roadmap must declare exactly one next task")

    rows = issue_rows(roadmap)
    next_rows = [number for number, state in rows.items() if "— next" in state]
    if len(next_rows) != 1 or next_rows[0] != next_tasks[0]:
        raise ValueError(
            "canonical issue map must mark exactly the declared next task as `active — next`"
        )

    if open_issues_path is not None:
        check_open_issues(rows, open_issues_path)

    repo_root = roadmap_path.resolve().parent
    check_local_links(roadmap_path, roadmap, repo_root)
    check_docs_layout(docs_root)
    for path in sorted(docs_root.rglob("*.md")):
        if is_hidden_path(path, docs_root):
            continue
        check_local_links(
            path,
            read_text(path, "source documentation"),
            repo_root,
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--roadmap", type=Path, default=Path("ROADMAP.md"))
    parser.add_argument(
        "--docs-index", type=Path, default=Path("docs/README.md")
    )
    parser.add_argument("--docs-root", type=Path, default=Path("docs"))
    parser.add_argument("--open-issues-json", type=Path)
    args = parser.parse_args()

    try:
        validate(
            args.roadmap,
            args.docs_index,
            args.docs_root,
            args.open_issues_json,
        )
    except (ValueError, json.JSONDecodeError) as error:
        return fail(str(error))

    print("Roadmap integrity verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
