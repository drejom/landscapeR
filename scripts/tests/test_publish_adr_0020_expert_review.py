"""Failure-boundary tests for the ADR 0020 Tally publishing helper."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest
from unittest import mock
import urllib.error


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "publish-adr-0020-expert-review.py"
SPEC = importlib.util.spec_from_file_location("publish_adr_0020_expert_review", MODULE_PATH)
PUBLISHER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(PUBLISHER)


class ApiRequestFailureTests(unittest.TestCase):
    @mock.patch.object(PUBLISHER.urllib.request, "urlopen")
    def test_url_error_becomes_clean_runtime_error(self, urlopen: mock.Mock) -> None:
        urlopen.side_effect = urllib.error.URLError("temporary DNS failure")

        with self.assertRaisesRegex(
            RuntimeError, "Tally API request failed: temporary DNS failure"
        ):
            PUBLISHER.api_request("POST", "/forms", "secret", {"name": "review"})

    @mock.patch.object(PUBLISHER.urllib.request, "urlopen")
    def test_timeout_becomes_clean_runtime_error(self, urlopen: mock.Mock) -> None:
        urlopen.side_effect = TimeoutError("request timed out")

        with self.assertRaisesRegex(
            RuntimeError, "Tally API request failed: request timed out"
        ):
            PUBLISHER.api_request("POST", "/forms", "secret", {"name": "review"})


if __name__ == "__main__":
    unittest.main()
