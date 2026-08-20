import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ACTION = ROOT / ".github/actions/setup-r-with-retry/action.yml"
WORKFLOW = ROOT / ".github/workflows/R-CMD-check.yaml"


class SetupRRetryContractTests(unittest.TestCase):
    def test_wrapper_has_two_recoverable_attempts_and_one_terminal_attempt(self):
        action = ACTION.read_text(encoding="utf-8")

        self.assertEqual(action.count("uses: r-lib/actions/setup-r@v2"), 3)
        self.assertEqual(action.count("continue-on-error: true"), 4)
        self.assertIn(
            "if: inputs.test-outcomes == '' && "
            "steps.setup-r-1.outcome == 'failure'",
            action,
        )
        self.assertIn(
            "if: inputs.test-outcomes == '' && "
            "steps.setup-r-1.outcome == 'failure' && "
            "steps.setup-r-2.outcome == 'failure'",
            action,
        )
        self.assertEqual(action.count("r-version: ${{ inputs.r-version }}"), 3)
        self.assertEqual(
            action.count("use-public-rspm: ${{ inputs.use-public-rspm }}"), 3
        )
        self.assertIn('test "$GITHUB_JOB" = setup-r-retry-contract', action)
        self.assertIn('test "$RETRY_R_VERSION" = test-fixture', action)
        self.assertNotIn('outcome="${{ inputs.test-outcomes }}"', action)
        self.assertIn("^(success|failure)(,(success|failure)){0,2}$", action)

    def test_runner_contract_exercises_recovery_and_terminal_failure(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")

        self.assertIn("setup-r-retry-contract:", workflow)
        self.assertIn("test-outcomes: failure,success", workflow)
        self.assertIn("test-outcomes: failure,failure,success", workflow)
        self.assertIn("test-outcomes: failure,failure,failure", workflow)
        self.assertIn('test "$RECOVER_SECOND" = success', workflow)
        self.assertIn('test "$RECOVER_THIRD" = success', workflow)
        self.assertIn('test "$TERMINAL_FAILURE" = failure', workflow)

    def test_check_and_pkgdown_use_the_same_wrapper(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        production_jobs = workflow.split("\n  R-CMD-check:", maxsplit=1)[1]

        self.assertEqual(
            production_jobs.count("uses: ./.github/actions/setup-r-with-retry"),
            2,
        )
        self.assertNotIn("uses: r-lib/actions/setup-r@v2", workflow)
        self.assertEqual(workflow.count('r-version: "4.5"'), 2)
        self.assertEqual(workflow.count("use-public-rspm: true"), 2)


if __name__ == "__main__":
    unittest.main()
