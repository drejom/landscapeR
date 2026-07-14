#!/usr/bin/env python3
"""CLI contract tests for the pull-request visual landing-proof policy."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-figure-review.py"


REQUIRED_PROOF = """\
## Visual landing proof

- [x] Proof required
- [ ] Exempt

**Proof type:** before-after
**Before:** The old workflow duplicates one omic layer before decomposition.
**After or representative output:** The new workflow runs registered SVD directly.
**Cold-reader conclusion:** K=1 now runs without a duplicated-omic-layer workaround.
**Reproduction:** Run `Rscript scripts/render-proof.R`.
**Claim status:** Implementation proof only; calibration-only and non-evidentiary.

### Current documentation

- [x] Updated
- [ ] Unaffected

**Documentation reference or rationale:** Development log K=1 section.
"""


VALID_EXEMPTION = """\
## Visual landing proof

- [ ] Proof required
- [x] Exempt

**Exemption category:** internal-only
**Exemption rationale:** This changes test fixture naming without changing any public, scientific, data, plotting, or developer-workflow behavior.
"""


class VisualProofCheckerCliTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp_dir.name)
        self._git("init", "-b", "main")
        self._git("config", "user.email", "test@example.invalid")
        self._git("config", "user.name", "Visual Proof Test")
        (self.repo / "README.md").write_text("base\n", encoding="utf-8")
        self._git("add", "README.md")
        self._git("commit", "-m", "base")
        self._git("switch", "-c", "feature")

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def _git(self, *args: str) -> None:
        subprocess.run(
            ["git", *args], cwd=self.repo, check=True,
            capture_output=True, text=True
        )

    def _commit_change(self, *, current_docs: bool = False) -> None:
        source = self.repo / "R" / "feature.R"
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_text("visible_feature <- TRUE\n", encoding="utf-8")
        if current_docs:
            vignette = self.repo / "vignettes" / "development-log.Rmd"
            vignette.parent.mkdir(parents=True, exist_ok=True)
            vignette.write_text("# Current workflow\n", encoding="utf-8")
        self._git("add", ".")
        self._git("commit", "-m", "feature")

    def _commit_path(self, path: str, content: str = "changed\n") -> None:
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        self._git("add", path)
        self._git("commit", "-m", f"change {path}")

    def _commit_obviously_public_change(self) -> None:
        self._commit_path("NAMESPACE", "export(public_feature)\n")

    def _run_checker(self, body: str) -> subprocess.CompletedProcess[str]:
        body_file = self.repo / "pr-body.md"
        body_file.write_text(body, encoding="utf-8")
        return subprocess.run(
            [sys.executable, str(CHECKER), str(body_file)],
            cwd=self.repo, capture_output=True, text=True
        )

    def test_requires_exactly_one_proof_classification(self) -> None:
        self._commit_change()
        neither = self._run_checker("## Visual landing proof\n")
        both = self._run_checker(REQUIRED_PROOF.replace(
            "- [ ] Exempt", "- [x] Exempt"
        ))

        self.assertNotEqual(neither.returncode, 0)
        self.assertIn("exactly one", neither.stderr)
        self.assertNotEqual(both.returncode, 0)
        self.assertIn("exactly one", both.stderr)

    def test_rejects_generic_exemption_rationale(self) -> None:
        self._commit_change()
        body = VALID_EXEMPTION.replace(
            "This changes test fixture naming without changing any public, scientific, data, plotting, or developer-workflow behavior.",
            "N/A"
        )
        result = self._run_checker(body)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("substantive exemption rationale", result.stderr)

    def test_accepts_substantive_categorized_exemption(self) -> None:
        self._commit_path("tests/testthat/helper-fixture.R", "fixture_name <- 'clearer'\n")
        result = self._run_checker(VALID_EXEMPTION)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Visual landing proof exemption accepted", result.stdout)

    def test_rejects_placeholder_prefixed_exemption_rationale(self) -> None:
        self._commit_path("tests/testthat/helper-fixture.R")
        body = VALID_EXEMPTION.replace(
            "This changes test fixture naming without changing any public, scientific, data, plotting, or developer-workflow behavior.",
            "N/A - this is long enough to bypass a length-only policy check."
        )
        result = self._run_checker(body)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("substantive exemption rationale", result.stderr)

    def test_rejects_exemption_for_obviously_public_change(self) -> None:
        self._commit_obviously_public_change()
        result = self._run_checker(VALID_EXEMPTION)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("obviously public", result.stderr)

    def test_rejects_exemption_for_prepared_data_workflow(self) -> None:
        self._commit_path("data-raw/prepare-cohort.R")
        result = self._run_checker(VALID_EXEMPTION)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("obviously public", result.stderr)

    def test_accepts_research_decision_only_exemption(self) -> None:
        self._commit_path("decisions/9999-proposed-research.md")
        body = VALID_EXEMPTION.replace(
            "internal-only", "research/decision-only"
        ).replace(
            "This changes test fixture naming without changing any public, scientific, data, plotting, or developer-workflow behavior.",
            "This records candidate research only and explicitly prohibits implementation until a later ADR is accepted."
        )
        result = self._run_checker(body)

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_required_proof_accepts_developer_workflow_with_docs_unaffected(self) -> None:
        self._commit_path("scripts/developer-status.py")
        body = REQUIRED_PROOF.replace("- [x] Updated", "- [ ] Updated").replace(
            "- [ ] Unaffected", "- [x] Unaffected"
        ).replace(
            "Development log K=1 section.",
            "The current user workflow is unchanged; the PR proof renders the developer-only status lifecycle."
        )
        result = self._run_checker(body)

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_template_comments_as_required_proof(self) -> None:
        self._commit_change(current_docs=True)
        body = REQUIRED_PROOF.replace(
            "The old workflow duplicates one omic layer before decomposition.",
            "<!-- Describe the old behavior. -->"
        )
        result = self._run_checker(body)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Before", result.stderr)

    def test_rejects_incomplete_required_proof_packet(self) -> None:
        self._commit_change(current_docs=True)
        body = REQUIRED_PROOF.replace(
            "K=1 now runs without a duplicated-omic-layer workaround.", ""
        )
        result = self._run_checker(body)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Cold-reader conclusion", result.stderr)

    def test_requires_declared_documentation_update_to_exist_in_diff(self) -> None:
        self._commit_change(current_docs=False)
        result = self._run_checker(REQUIRED_PROOF)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("current documentation", result.stderr)

    def test_accepts_complete_required_proof_with_current_docs(self) -> None:
        self._commit_change(current_docs=True)
        result = self._run_checker(REQUIRED_PROOF)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Visual landing proof packet accepted", result.stdout)

    def test_accepts_complete_proof_when_docs_are_substantively_unaffected(self) -> None:
        self._commit_change(current_docs=False)
        body = REQUIRED_PROOF.replace("- [x] Updated", "- [ ] Updated").replace(
            "- [ ] Unaffected", "- [x] Unaffected"
        ).replace(
            "Development log K=1 section.",
            "The documented public workflow is unchanged; this proof covers developer-only status rendering."
        )
        result = self._run_checker(body)

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_legacy_nonempty_na_figure_review(self) -> None:
        self._commit_change(current_docs=True)
        result = self._run_checker(
            "## Figures\n\n**Figure review**\n\n- N/A\n"
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exactly one", result.stderr)


if __name__ == "__main__":
    unittest.main()
