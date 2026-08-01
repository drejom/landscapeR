import subprocess
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-repo-hygiene.sh"


class RepoHygieneCheckerTests(unittest.TestCase):
    def make_repo(self):
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        subprocess.run(["git", "init", "-q", str(root)], check=True)
        (root / ".gitignore").write_text(".claude/\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(root), "add", ".gitignore"], check=True)
        return temporary, root

    def run_checker(self, root):
        return subprocess.run(
            ["bash", str(CHECKER), str(root)],
            text=True,
            capture_output=True,
            check=False,
        )

    def test_clean_worktree_passes(self):
        temporary, root = self.make_repo()
        self.addCleanup(temporary.cleanup)
        result = self.run_checker(root)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_scratch_output_passes_even_before_ignore_rule_is_loaded(self):
        temporary, root = self.make_repo()
        self.addCleanup(temporary.cleanup)
        scratch = root / ".scratch" / "task"
        scratch.mkdir(parents=True)
        (scratch / "figure.png").write_text("proof", encoding="utf-8")
        result = self.run_checker(root)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_existing_ignored_tool_output_passes(self):
        temporary, root = self.make_repo()
        self.addCleanup(temporary.cleanup)
        ignored = root / ".claude"
        ignored.mkdir()
        (ignored / "state.json").write_text("{}", encoding="utf-8")
        result = self.run_checker(root)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_untracked_output_outside_scratch_fails(self):
        temporary, root = self.make_repo()
        self.addCleanup(temporary.cleanup)
        (root / "Rplots.pdf").write_text("residue", encoding="utf-8")
        result = self.run_checker(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn("Rplots.pdf", result.stderr)
        self.assertIn("outside .scratch/", result.stderr)

    def test_nested_scratch_directory_is_not_treated_as_repo_scratch(self):
        temporary, root = self.make_repo()
        self.addCleanup(temporary.cleanup)
        (root / ".gitignore").write_text(
            ".claude/\n/.scratch/\n", encoding="utf-8"
        )
        nested = root / "R" / ".scratch"
        nested.mkdir(parents=True)
        (nested / "state.rds").write_text("residue", encoding="utf-8")
        result = self.run_checker(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn("R/.scratch/state.rds", result.stderr)

    def test_tracked_modification_is_not_transient_residue(self):
        temporary, root = self.make_repo()
        self.addCleanup(temporary.cleanup)
        (root / ".gitignore").write_text(".claude/\n.scratch/\n", encoding="utf-8")
        result = self.run_checker(root)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
