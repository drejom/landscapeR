#!/usr/bin/env python3
"""CLI contract tests for the authoritative roadmap checker."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-roadmap.py"

VALID_ROADMAP = """\
# landscapeR roadmap

**Scheduling authority:** This is the single authoritative run sheet.

**Next task after this roadmap lands:** **#1 — First task**.

# Active milestone — example

<!-- issue-map:start -->
| Issue | Roadmap lane | State |
|---|---|---|
| [#1](https://github.com/drejom/landscapeR/issues/1) | Active lane | active — next |
| [#2](https://github.com/drejom/landscapeR/issues/2) | Later lane | parked |
| [#3](https://github.com/drejom/landscapeR/issues/3) | Bootstrap | complete on merge |
<!-- issue-map:end -->

# Change control
"""

DOCS_INDEX = """\
# Documentation map

See the [roadmap](../ROADMAP.md).
"""


class RoadmapCheckerCliTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp_dir.name)
        (self.repo / "docs").mkdir()
        (self.repo / "ROADMAP.md").write_text(VALID_ROADMAP, encoding="utf-8")
        (self.repo / "docs" / "README.md").write_text(DOCS_INDEX, encoding="utf-8")
        self.open_issues = self.repo / "open-issues.json"
        self.open_issues.write_text(
            json.dumps([{"number": 1}, {"number": 2}, {"number": 3}]),
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def _run(self, *extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(CHECKER),
                "--roadmap",
                "ROADMAP.md",
                "--docs-index",
                "docs/README.md",
                *extra,
            ],
            cwd=self.repo,
            capture_output=True,
            text=True,
        )

    def test_accepts_complete_authoritative_roadmap(self) -> None:
        result = self._run("--open-issues-json", str(self.open_issues))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Roadmap integrity verified", result.stdout)

    def test_requires_authority_declaration(self) -> None:
        path = self.repo / "ROADMAP.md"
        path.write_text(
            VALID_ROADMAP.replace("**Scheduling authority:**", "**Planning note:**"),
            encoding="utf-8",
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Scheduling authority", result.stderr)

    def test_requires_exactly_one_next_task(self) -> None:
        path = self.repo / "ROADMAP.md"
        path.write_text(
            VALID_ROADMAP.replace(
                "# Active milestone — example",
                "**Next task:** **#2 — Other**.\n\n# Active milestone — example",
            ),
            encoding="utf-8",
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exactly one next task", result.stderr)

    def test_rejects_duplicate_issue_rows(self) -> None:
        path = self.repo / "ROADMAP.md"
        path.write_text(
            VALID_ROADMAP.replace(
                "<!-- issue-map:end -->",
                "| [#2](https://github.com/drejom/landscapeR/issues/2) | Duplicate | queued |\n<!-- issue-map:end -->",
            ),
            encoding="utf-8",
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate issue", result.stderr)

    def test_rejects_unmapped_open_issue(self) -> None:
        self.open_issues.write_text(
            json.dumps([{"number": 1}, {"number": 2}, {"number": 4}]),
            encoding="utf-8",
        )

        result = self._run("--open-issues-json", str(self.open_issues))

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("open issues missing", result.stderr)
        self.assertIn("#4", result.stderr)

    def test_allows_completed_bootstrap_row_after_issue_closes(self) -> None:
        self.open_issues.write_text(
            json.dumps([{"number": 1}, {"number": 2}]),
            encoding="utf-8",
        )

        result = self._run("--open-issues-json", str(self.open_issues))

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_nonexistent_relative_link(self) -> None:
        path = self.repo / "docs" / "README.md"
        path.write_text("See [missing](missing.md).\n", encoding="utf-8")

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("broken local link", result.stderr)

    def test_checks_links_in_nested_source_documentation(self) -> None:
        nested = self.repo / "docs" / "archive"
        nested.mkdir()
        (nested / "old-plan.md").write_text(
            "See [missing](../plans/missing.md).\n", encoding="utf-8"
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("old-plan.md", result.stderr)

    def test_rejects_generated_output_under_source_docs(self) -> None:
        (self.repo / "docs" / "index.html").write_text(
            "<html>generated</html>\n", encoding="utf-8"
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("generated or uncategorized", result.stderr)

    def test_allows_versioned_review_markdown_and_json(self) -> None:
        reviews = self.repo / "docs" / "reviews"
        reviews.mkdir()
        (reviews / "questionnaire.md").write_text("# Review\n", encoding="utf-8")
        (reviews / "questionnaire.json").write_text("{}\n", encoding="utf-8")

        result = self._run()

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_allows_primary_source_research_markdown(self) -> None:
        research = self.repo / "docs" / "research"
        research.mkdir()
        (research / "method-note.md").write_text(
            "# Primary-source method note\n", encoding="utf-8"
        )

        result = self._run()

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_json_outside_review_instruments(self) -> None:
        plans = self.repo / "docs" / "plans"
        plans.mkdir()
        (plans / "generated.json").write_text("{}\n", encoding="utf-8")

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("generated or uncategorized", result.stderr)

    def test_ignores_hidden_operating_system_files(self) -> None:
        (self.repo / "docs" / ".DS_Store").write_text("metadata", encoding="utf-8")

        result = self._run()

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_empty_markdown_link_without_traceback(self) -> None:
        (self.repo / "docs" / "README.md").write_text(
            "See [empty]().\n", encoding="utf-8"
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("empty Markdown link", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_rejects_absolute_local_link(self) -> None:
        (self.repo / "docs" / "README.md").write_text(
            "See [host file](/etc/hosts).\n", encoding="utf-8"
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("outside repository", result.stderr)

    def test_rejects_traversal_to_existing_file_outside_repository(self) -> None:
        outside = self.repo.parent / f"{self.repo.name}-outside.md"
        outside.write_text("outside\n", encoding="utf-8")
        self.addCleanup(outside.unlink)
        (self.repo / "docs" / "README.md").write_text(
            f"See [outside](../../{outside.name}).\n", encoding="utf-8"
        )

        result = self._run()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("outside repository", result.stderr)


if __name__ == "__main__":
    unittest.main()
