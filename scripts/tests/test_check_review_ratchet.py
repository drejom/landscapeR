import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-review-ratchet.py"


VALID_DOCUMENT = """# Review ratchet
## Gate sequence
Sequence.
## Never-touch list
None yet.
## Earned defect checklist
### RR-001 — Wait for review
Wait for review.
**Incident:** repository PR #137
## Verify, never assume
Verify findings.
## Maintenance duties
Add, correct, deduplicate, and graduate.
"""

VALID_BODY = """## Review ratchet
- [ ] Unchanged
- [x] Updated
- [ ] Corrected
- [ ] Deduplicated
- [ ] Graduated
**Ratchet rationale:** Added the incident-backed rule earned by this pull request.
"""


class ReviewRatchetCheckerTests(unittest.TestCase):
    def run_checker(self, document=VALID_DOCUMENT, body=VALID_BODY):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        document_path = root / "ratchet.md"
        body_path = root / "body.md"
        document_path.write_text(document, encoding="utf-8")
        body_path.write_text(body, encoding="utf-8")
        return subprocess.run(
            [
                sys.executable, str(CHECKER), "--document", str(document_path),
                "--pr-body", str(body_path),
            ],
            text=True, capture_output=True, check=False,
        )

    def test_valid_document_and_pr_disposition_pass(self):
        result = self.run_checker()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_required_section_fails(self):
        result = self.run_checker(VALID_DOCUMENT.replace("## Gate sequence", "## Sequence"))
        self.assertIn("missing required section: Gate sequence", result.stderr)

    def test_duplicate_required_section_fails(self):
        duplicate = VALID_DOCUMENT + "\n## Gate sequence\nConflicting sequence.\n"
        result = self.run_checker(duplicate)
        self.assertIn("duplicate required section: Gate sequence", result.stderr)

    def test_line_cap_is_enforced(self):
        result = self.run_checker(VALID_DOCUMENT + "filler\n" * 151)
        self.assertIn("150-line readability cap", result.stderr)

    def test_duplicate_entry_identifier_fails(self):
        duplicate = VALID_DOCUMENT.replace(
            "## Verify, never assume",
            "### RR-001 — Repeat\n**Incident:** repository PR #138\n## Verify, never assume",
        )
        result = self.run_checker(duplicate)
        self.assertIn("duplicate review-ratchet identifiers", result.stderr)

    def test_malformed_earned_entry_heading_fails(self):
        malformed = VALID_DOCUMENT.replace(
            "### RR-001 — Wait for review", "### Wait for review"
        )
        result = self.run_checker(malformed)
        self.assertIn("malformed earned entry headings", result.stderr)

    def test_entry_without_incident_fails(self):
        result = self.run_checker(VALID_DOCUMENT.replace("repository PR #137", "an anecdote"))
        self.assertIn("lacks a concrete repository incident", result.stderr)

    def test_exactly_one_disposition_is_required(self):
        result = self.run_checker(VALID_DOCUMENT, VALID_BODY.replace("[ ] Unchanged", "[x] Unchanged"))
        self.assertIn("select exactly one", result.stderr)

    def test_duplicate_checked_disposition_rows_fail(self):
        duplicated = VALID_BODY.replace(
            "- [x] Updated", "- [x] Updated\n- [x] Updated"
        )
        result = self.run_checker(VALID_DOCUMENT, duplicated)
        self.assertIn("duplicate review-ratchet dispositions: Updated", result.stderr)

    def test_unchecked_duplicate_cannot_hide_later_checked_row(self):
        duplicated = VALID_BODY.replace(
            "- [x] Updated", "- [ ] Updated\n- [x] Updated"
        )
        result = self.run_checker(VALID_DOCUMENT, duplicated)
        self.assertIn("duplicate review-ratchet dispositions: Updated", result.stderr)

    def test_every_permitted_disposition_passes(self):
        for disposition in (
            "Unchanged", "Updated", "Corrected", "Deduplicated", "Graduated"
        ):
            with self.subTest(disposition=disposition):
                body = VALID_BODY.replace("[x] Updated", "[ ] Updated")
                body = body.replace(f"[ ] {disposition}", f"[x] {disposition}")
                result = self.run_checker(VALID_DOCUMENT, body)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_equivalent_markdown_checkbox_formatting_passes(self):
        formatted = VALID_BODY.replace("- [x] Updated", "  *   [X]   Updated")
        result = self.run_checker(VALID_DOCUMENT, formatted)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_disposition_text_outside_ratchet_section_does_not_count(self):
        ratchet_unchecked = VALID_BODY.replace("[x] Updated", "[ ] Updated")
        spoofed = (
            "## Current documentation\n- [x] Updated\n"
            "**Ratchet rationale:** This rationale is outside the governed section.\n"
            + ratchet_unchecked.replace(
                "Added the incident-backed rule earned by this pull request.", ""
            )
        )
        result = self.run_checker(VALID_DOCUMENT, spoofed)
        self.assertIn("select exactly one", result.stderr)
        self.assertIn("substantive rationale", result.stderr)

    def test_duplicate_review_ratchet_section_fails(self):
        result = self.run_checker(
            VALID_DOCUMENT,
            VALID_BODY + "\n## Review ratchet\nConflicting disposition.\n",
        )
        self.assertIn("duplicate Review ratchet sections", result.stderr)

    def test_empty_review_ratchet_section_fails_without_traceback(self):
        result = self.run_checker(VALID_DOCUMENT, "## Review ratchet")
        self.assertEqual(result.returncode, 1)
        self.assertIn("select exactly one", result.stderr)
        self.assertIn("substantive rationale", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_disposition_requires_substantive_rationale(self):
        result = self.run_checker(VALID_DOCUMENT, VALID_BODY.replace(
            "Added the incident-backed rule earned by this pull request.", "N/A"
        ))
        self.assertIn("substantive rationale", result.stderr)

    def test_placeholder_prefixed_rationales_fail(self):
        for placeholder in (
            "N/A - this text only pads the rejected placeholder",
            "TODO: replace this with a real rationale later",
            "None — because no substantive explanation was supplied",
        ):
            with self.subTest(placeholder=placeholder):
                body = VALID_BODY.replace(
                    "Added the incident-backed rule earned by this pull request.",
                    placeholder,
                )
                result = self.run_checker(VALID_DOCUMENT, body)
                self.assertIn("substantive rationale", result.stderr)

    def test_ordinary_prose_beginning_with_placeholder_words_passes(self):
        for rationale in (
            "None of the review findings changed the governed rule, so the "
            "ratchet remains unchanged.",
            "NA handling was unchanged because this pull request did not touch "
            "the package data boundary.",
        ):
            with self.subTest(rationale=rationale):
                body = VALID_BODY.replace(
                    "Added the incident-backed rule earned by this pull request.",
                    rationale,
                )
                result = self.run_checker(VALID_DOCUMENT, body)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_multiline_disposition_rationale_passes(self):
        multiline = VALID_BODY.replace(
            "**Ratchet rationale:** Added the incident-backed rule earned by this pull request.",
            "**Ratchet rationale:**\nAdded the incident-backed rule earned by\n"
            "this pull request after verifying the concrete review incident.",
        )
        result = self.run_checker(VALID_DOCUMENT, multiline)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
