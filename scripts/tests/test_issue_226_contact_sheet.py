#!/usr/bin/env python3
"""Tests for the committed issue #226 public-plot contract checker."""

from __future__ import annotations

import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHECKER_PATH = ROOT / "scripts" / "check-issue-226-contact-sheet.py"
SPEC = importlib.util.spec_from_file_location("issue_226_checker", CHECKER_PATH)
assert SPEC and SPEC.loader
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


class Issue226ContactSheetContractTest(unittest.TestCase):
    def _copy_contract(self, temporary: str) -> Path:
        root = Path(temporary)
        shutil.copy(ROOT / "NAMESPACE", root / "NAMESPACE")
        (root / "scripts").mkdir()
        shutil.copy(
            ROOT / "scripts" / "render-issue-226-contact-sheet.R",
            root / "scripts" / "render-issue-226-contact-sheet.R",
        )
        (root / "R").mkdir()
        shutil.copy(
            ROOT / "R" / "13q-contact-sheet.R",
            root / "R" / "13q-contact-sheet.R",
        )
        (root / ".github" / "landing-proof").mkdir(parents=True)
        proof = root / ".github" / "landing-proof" / "issue-226"
        shutil.copytree(ROOT / ".github" / "landing-proof" / "issue-226", proof)
        return root

    def test_committed_contract_is_valid(self) -> None:
        messages = CHECKER.check_contact_sheet_contract(ROOT)
        self.assertEqual(len(messages), 3)

    def test_checker_rejects_inventory_symbol_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "NAMESPACE").write_text(
                "export(plot_example)\n", encoding="utf-8"
            )
            proof = root / ".github" / "landing-proof" / "issue-226"
            proof.mkdir(parents=True)
            (proof / "public-plot-inventory.tsv").write_text(
                "id\tincluded\tfunction_name\tfigure\tcaption\texclusion_reason\n"
                "example\tTRUE\tplot_other\tfigure.png\tcaption.txt\t\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "out of sync with NAMESPACE"):
                CHECKER.check_contact_sheet_contract(root)

    def test_checker_rejects_missing_retained_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = self._copy_contract(temporary)
            (root / ".github" / "landing-proof" / "issue-226" /
             "stage1-spectrum.png").unlink()
            with self.assertRaisesRegex(ValueError, "missing included figure"):
                CHECKER.check_contact_sheet_contract(root)

    def test_checker_rejects_missing_reduced_contact_sheet(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = self._copy_contract(temporary)
            (root / ".github" / "landing-proof" / "issue-226" /
             "public-plot-contact-sheet-reduced.png").unlink()
            with self.assertRaisesRegex(ValueError, "missing contact-sheet QA artifact"):
                CHECKER.check_contact_sheet_contract(root)

    def test_checker_rejects_missing_tile_label_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = self._copy_contract(temporary)
            (root / ".github" / "landing-proof" / "issue-226" /
             "public-plot-contact-sheet-labels.tsv").unlink()
            with self.assertRaisesRegex(ValueError, "tile-label contract"):
                CHECKER.check_contact_sheet_contract(root)

    def test_checker_rejects_overlong_tile_label(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = self._copy_contract(temporary)
            labels = (root / ".github" / "landing-proof" / "issue-226" /
                      "public-plot-contact-sheet-labels.tsv")
            text = labels.read_text(encoding="utf-8")
            labels.write_text(text.replace("Association atlas", "A" * 26, 1),
                              encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "exceeds 25"):
                CHECKER.check_contact_sheet_contract(root)

    def test_checker_rejects_non_reduced_contact_sheet(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = self._copy_contract(temporary)
            proof = root / ".github" / "landing-proof" / "issue-226"
            shutil.copy(proof / "public-plot-contact-sheet.png",
                        proof / "public-plot-contact-sheet-reduced.png")
            with self.assertRaisesRegex(ValueError, "strictly smaller"):
                CHECKER.check_contact_sheet_contract(root)

    def test_checker_rejects_invalid_included_excluded_counts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = self._copy_contract(temporary)
            inventory = (
                root / ".github" / "landing-proof" / "issue-226"
                / "public-plot-inventory.tsv"
            )
            text = inventory.read_text(encoding="utf-8")
            inventory.write_text(
                text.replace("\tTRUE\t", "\tFALSE\t", 1),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "17 included and 7 excluded"):
                CHECKER.check_contact_sheet_contract(root)

    def test_checker_rejects_renderer_symbol_omission(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = self._copy_contract(temporary)
            renderer = root / "scripts" / "render-issue-226-contact-sheet.R"
            renderer.write_text(
                renderer.read_text(encoding="utf-8").replace(
                    "plot_components", "plot_components_missing"
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "does not mention inventory symbols"):
                CHECKER.check_contact_sheet_contract(root)


if __name__ == "__main__":
    unittest.main()
