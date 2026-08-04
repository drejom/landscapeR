import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "classify-package-check.py"
ROOT = Path(__file__).resolve().parents[2]


class PackageCheckClassificationTests(unittest.TestCase):
    def classify(self, paths, zero=False, force=False):
        command = [sys.executable, str(CHECKER)]
        payload = ""
        if force:
            command.append("--force-full")
        elif zero:
            command.append("--stdin-zero")
            payload = "\0".join(paths) + "\0"
        else:
            command.append("--stdin")
            payload = "\n".join(paths) + "\n"
        return subprocess.run(
            command, input=payload, text=True, capture_output=True, check=False
        )

    def test_source_tests_metadata_and_generated_reference_are_full(self):
        for path in ("R/runner.R", "tests/testthat/test-runner.R", "DESCRIPTION", "NAMESPACE", "man/run_pipeline.Rd"):
            with self.subTest(path=path):
                result = self.classify([path])
                self.assertEqual(result.stdout.strip(), "full")

    def test_documentation_only_changes_use_short_path(self):
        result = self.classify([
            "README.md", "docs/agents/ci-check-selection.md",
            "decisions/0020-stage1-component-interpretation-strategy.md",
            ".github/landing-proof/issue-130/workflow-run.png",
            ".github/ISSUE_TEMPLATE/bug.yml",
        ])
        self.assertEqual(result.stdout.strip(), "docs-only")

    def test_mixed_diff_uses_full_path(self):
        result = self.classify(["docs/README.md", "tests/testthat/test-runner.R"])
        self.assertEqual(result.stdout.strip(), "full")

    def test_execution_files_cannot_hide_under_documentation_paths(self):
        for path in (
            "docs/tool.py", "docs/data.rds", "R/notes.md",
            ".github/workflows/notes.md", ".github/landing-proof/issue-130/reproduce.R",
        ):
            with self.subTest(path=path):
                self.assertEqual(self.classify([path]).stdout.strip(), "full")

    def test_unknown_and_empty_diffs_fail_safe_to_full(self):
        self.assertEqual(self.classify(["configure"]).stdout.strip(), "full")
        self.assertEqual(self.classify([]).stdout.strip(), "full")

    def test_nul_delimited_input_preserves_paths_with_spaces(self):
        result = self.classify(["docs/design notes.md", "R/file name.R"], zero=True)
        self.assertEqual(result.stdout.strip(), "full")

    def test_force_full_supports_push_events(self):
        self.assertEqual(self.classify([], force=True).stdout.strip(), "full")

    def test_github_output_records_boolean_and_scope(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "output"
            result = subprocess.run(
                [sys.executable, str(CHECKER), "--github-output", str(output), "docs/README.md"],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(output.read_text(encoding="utf-8"), "run_full=false\nscope=docs-only\n")

    def test_required_job_is_always_present_and_uses_shared_policy(self):
        workflow = (ROOT / ".github/workflows/R-CMD-check.yaml").read_text(encoding="utf-8")
        package_job = workflow.split("\n  lint:", maxsplit=1)[0]
        self.assertNotIn("  R-CMD-check:\n    if:", package_job)
        self.assertIn("scripts/classify-package-check.py --stdin-zero", package_job)
        self.assertIn("steps.package-check.outputs.run_full == 'true'", package_job)

        hook = (ROOT / "hooks/pre-push").read_text(encoding="utf-8")
        self.assertIn("python3 scripts/classify-package-check.py --stdin", hook)


if __name__ == "__main__":
    unittest.main()
