#!/usr/bin/env python3
"""Contract tests for the tracked cluster-neutral K=1 deployer."""

import os
import pathlib
import subprocess
import unittest


ROOT = pathlib.Path(__file__).parents[2]
SCRIPT = ROOT / "scripts" / "deploy-k1-revised-acceptance.sh"


class DeploymentContractTest(unittest.TestCase):
    def test_script_uses_cluster_owned_runtime_contract(self):
        text = SCRIPT.read_text()
        for required in ("scp", "ssh", "validate_cluster", "get_library_path", "get_container_path", "run_in_container", "pak::pkg_install", "pak::local_install", "BIOCONDUCTOR_VERSION", "merge-base", "k1-revised-acceptance-payload-digest.sh", '"-l", reference_library'):
            self.assertIn(required, text)
        for forbidden in ("/packages/", "/opt/singularity", "controller_constructor"):
            self.assertNotIn(forbidden, text.lower())

    def test_dry_run_is_reproducible_and_does_not_contact_remote(self):
        if subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=ROOT, text=True
        ).strip():
            self.skipTest("dry-run packaging contract requires a clean checkout")
        source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        protocol = "f668e1e0f49f66b8bd8c244ca6fb667a9b39d896"
        archive_hashes = []
        for host in ("apollo", "gemini"):
            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--remote-host", host,
                    "--remote-config", "/path/to/rbiocverse/cluster-config.sh",
                    "--remote-run-root", "/shared/landscapeR/k1-revised-acceptance",
                    "--source-revision", source,
                    "--protocol-merge", protocol,
                    "--runner-merge", source,
                    "--dry-run",
                ],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=True,
                env={**os.environ, "LANDSCAPER_DEPLOY_SCRATCH": str(ROOT / ".scratch")},
            )
            self.assertIn("DRY RUN: scp archive", result.stdout)
            self.assertIn(f"DRY RUN: ssh {host}", result.stdout)
            self.assertNotIn("landscapeR-source.tar.gz", result.stderr)
            archive_hashes.append(
                next(
                    line.split(":", 1)[1].strip()
                    for line in result.stdout.splitlines()
                    if line.startswith("  archive SHA-256:")
                )
            )
        self.assertEqual(len(set(archive_hashes)), 1)

    def test_submission_is_explicit(self):
        result = subprocess.run(
            [str(SCRIPT), "--help"], cwd=ROOT, text=True, capture_output=True, check=True
        )
        self.assertIn("Without --submit", result.stdout)

    def test_public_proof_redacts_cluster_identifiers(self):
        proof = (ROOT / ".github" / "landing-proof" / "issue-249" / "deployment-dry-run.txt").read_text()
        self.assertNotIn("apollo", proof.lower())
        self.assertNotIn("gemini", proof.lower())
        self.assertNotIn("/shared/", proof)


if __name__ == "__main__":
    unittest.main()
