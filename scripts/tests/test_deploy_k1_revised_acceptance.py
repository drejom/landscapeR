#!/usr/bin/env python3
"""Contract tests for the tracked cluster-neutral K=1 deployer."""

import os
import hashlib
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).parents[2]
SCRIPT = ROOT / "scripts" / "deploy-k1-revised-acceptance.sh"


class DeploymentContractTest(unittest.TestCase):
    def test_script_uses_cluster_owned_runtime_contract(self):
        text = SCRIPT.read_text()
        for required in ("scp", "ssh", "hprcc::get_cluster", 'getFromNamespace("singularity_container", "hprcc")', 'getFromNamespace("r_libs_site", "hprcc")', "pak::pkg_install", "pak::local_install", "BIOCONDUCTOR_VERSION", "merge-base", "k1-revised-acceptance-payload-digest.sh", "payload_verifier_sha256", "preflight_sha256", "trusted_source_sha", "trusted_payload_verifier_sha", "trusted_preflight_sha", "preflight_lock", "write_record", '"-l", reference_library', "REMOTE PREFLIGHT"):
            self.assertIn(required, text)
        for forbidden in ("/packages/", "/opt/singularity", "cluster-config.sh", "rbiocverse_config", "remote-config", "validate_cluster", "get_library_path", "get_container_path", "run_in_container", "controller_constructor"):
            self.assertNotIn(forbidden.lower(), text.lower())

    def test_dry_run_is_reproducible_and_does_not_contact_remote(self):
        if subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=ROOT, text=True
        ).strip():
            self.skipTest("dry-run packaging contract requires a clean checkout")
        source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        protocol = "f668e1e0f49f66b8bd8c244ca6fb667a9b39d896"
        archive_hashes = []
        preflight_hashes = []
        for host in ("apollo", "gemini"):
            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--remote-host", host,
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
            self.assertIn("active hprcc/rbiocverse Slurm session", result.stdout)
            self.assertNotIn("landscapeR-source.tar.gz", result.stderr)
            archive_hashes.append(
                next(
                    line.split(":", 1)[1].strip()
                    for line in result.stdout.splitlines()
                    if line.startswith("  archive SHA-256:")
                )
            )
            preflight_hashes.append(
                next(
                    line.split(":", 1)[1].strip()
                    for line in result.stdout.splitlines()
                    if line.startswith("  preflight SHA-256:")
                )
            )
        self.assertEqual(len(set(archive_hashes)), 1)
        self.assertEqual(len(set(preflight_hashes)), 1)

    def test_submission_is_explicit(self):
        result = subprocess.run(
            [str(SCRIPT), "--help"], cwd=ROOT, text=True, capture_output=True, check=True
        )
        self.assertIn("Without --submit", result.stdout)

    def test_generated_handoff_enforces_session_and_launcher_boundary(self):
        text = SCRIPT.read_text()
        marker = 'cat > "$bundle_root/remote-preflight.R" <<\'REMOTE_R\'\n'
        self.assertIn(marker, text, "the deployer must embed its reviewed preflight")
        start = text.index(marker) + len(marker)
        end = text.index("\nREMOTE_R\n", start)
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            preflight = root / "remote-preflight.R"
            preflight.write_text(text[start:end])
            valid_args = [
                "source.tar.gz",
                str(root / "run"),
                "a" * 40,
                "b" * 40,
                "c" * 40,
                "3.22",
                "d" * 64,
                "e" * 64,
                "false",
            ]
            environment = os.environ.copy()
            environment.pop("SLURM_JOB_ID", None)
            environment.pop("SINGULARITY_CONTAINER", None)
            preflight_result = subprocess.run(
                ["Rscript", "--vanilla", str(preflight), *valid_args],
                text=True,
                capture_output=True,
                env=environment,
                check=False,
            )
            self.assertNotEqual(preflight_result.returncode, 0)
            self.assertIn(
                "active rbiocverse Slurm session",
                preflight_result.stderr + preflight_result.stdout,
            )

            fake_bin = root / "bin"
            fake_bin.mkdir()
            invocation = root / "rscript-invocation.txt"
            fake_rscript = fake_bin / "Rscript"
            fake_rscript.write_text(
                "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$FAKE_RSCRIPT_LOG\"\n"
            )
            fake_rscript.chmod(0o755)
            payload = root / "payload.sh"
            payload.write_text("#!/bin/sh\nexit 0\n")
            payload.chmod(0o755)
            sif = root / "rbiocverse_3.22.sif"
            sif.touch()
            launcher = ROOT / "inst" / "extdata" / "k1-revised-acceptance-launch.sh"
            launcher_environment = os.environ.copy()
            launcher_environment.update(
                {
                    "PATH": f"{fake_bin}{os.pathsep}{launcher_environment['PATH']}",
                    "FAKE_RSCRIPT_LOG": str(invocation),
                    "SLURM_JOB_ID": "12345",
                    "SINGULARITY_CONTAINER": str(sif),
                    "BIOCONDUCTOR_VERSION": "3.22",
                    "LANDSCAPER_K1_PROTOCOL_MERGE": "b" * 40,
                    "LANDSCAPER_K1_RUNNER_MERGE": "c" * 40,
                    "LANDSCAPER_PAYLOAD_SHA256": "a" * 64,
                    "LANDSCAPER_PAYLOAD_VERIFIER": str(payload),
                    "LANDSCAPER_PAYLOAD_VERIFIER_SHA256": hashlib.sha256(
                        payload.read_bytes()
                    ).hexdigest(),
                    "LANDSCAPER_RUN_ROOT": str(root),
                }
            )
            launcher_result = subprocess.run(
                ["bash", str(launcher)],
                text=True,
                capture_output=True,
                env=launcher_environment,
                check=False,
            )
            self.assertEqual(launcher_result.returncode, 0, launcher_result.stderr)
            invocation_text = invocation.read_text()
            self.assertIn("--vanilla", invocation_text)
            self.assertIn("targets::tar_make", invocation_text)
            self.assertIn('getFromNamespace("r_libs_site", "hprcc")', invocation_text)

    def test_public_proof_redacts_cluster_identifiers(self):
        proof = (ROOT / ".github" / "landing-proof" / "issue-249" / "deployment-dry-run.txt").read_text()
        self.assertNotIn("apollo", proof.lower())
        self.assertNotIn("gemini", proof.lower())
        self.assertNotIn("/shared/", proof)


if __name__ == "__main__":
    unittest.main()
