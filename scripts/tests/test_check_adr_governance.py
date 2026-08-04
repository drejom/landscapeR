import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-adr-governance.py"


class AdrGovernanceCheckerTests(unittest.TestCase):
    def run_checker(self, files):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        decisions = Path(temporary.name)
        for name, body in files.items():
            (decisions / name).write_text(body, encoding="utf-8")
        return subprocess.run(
            [sys.executable, str(CHECKER), "--decisions-dir", str(decisions)],
            text=True, capture_output=True, check=False,
        )

    def test_valid_statuses_and_resolution_metadata_pass(self):
        result = self.run_checker({
            "0001-first.md": "# 0001\n**Status:** accepted\n",
            "0002-second.md": "# 0002\n**Status:** provisional-accepted\n**Resolution issue:** #51\n",
            "0003-third.md": "# 0003\n**Status:** reopened\n**Resolution issue:** #49\n",
        })
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_duplicate_active_number_fails(self):
        result = self.run_checker({
            "0001-first.md": "# 0001\n**Status:** accepted\n",
            "0001-second.md": "# 0001\n**Status:** rejected\n",
        })
        self.assertIn("duplicate active ADR number 0001", result.stderr)

    def test_invalid_status_fails(self):
        result = self.run_checker({"0001-first.md": "# 0001\n**Status:** provisional\n"})
        self.assertIn("invalid ADR status", result.stderr)

    def test_contradictory_status_declaration_fails(self):
        result = self.run_checker({
            "0001-first.md": "# 0001\n**Status:** proposed\n**Status: accepted**\n"
        })
        self.assertIn("exactly one canonical", result.stderr)

    def test_open_status_without_resolution_issue_fails(self):
        for status in ("provisional-accepted", "reopened"):
            with self.subTest(status=status):
                result = self.run_checker({
                    "0001-first.md": f"# 0001\n**Status:** {status}\n"
                })
                self.assertIn("requires exactly one", result.stderr)


if __name__ == "__main__":
    unittest.main()
