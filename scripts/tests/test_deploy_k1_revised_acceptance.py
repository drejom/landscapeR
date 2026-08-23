#!/usr/bin/env python3
"""Contract tests for the tracked cluster-neutral K=1 deployer."""

import os
import hashlib
import pathlib
import shutil
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
        if shutil.which("Rscript") is None:
            self.skipTest("Rscript is required for the embedded preflight test")
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

    def test_hprcc_resolver_accepts_each_supported_cluster(self):
        r_executable = shutil.which("R")
        rscript_executable = shutil.which("Rscript")
        if r_executable is None or rscript_executable is None:
            self.skipTest("R and Rscript are required for the hprcc resolver test")
        text = SCRIPT.read_text()
        start_marker = "runtime_libraries <- unlist(lapply("
        end_marker = "\nif (!dir.exists(run_root)"
        start = text.index(start_marker)
        end = text.index(end_marker, start)
        resolver = text[start:end]
        self.assertLess(
            start,
            text.index('if (!requireNamespace("hprcc", quietly = TRUE)) {', start),
            "the active runtime library must be prepended before hprcc loads",
        )

        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            def install_hprcc(library, version, implementation):
                package_source = root / ("hprcc-" + version)
                (package_source / "R").mkdir(parents=True)
                (package_source / "DESCRIPTION").write_text(
                    "Package: hprcc\n"
                    "Type: Package\n"
                    "Title: Deployment resolver test double\n"
                    f"Version: {version}\n"
                    "Authors@R: person('Test', 'Harness', email = 'test@example.org', role = c('aut', 'cre'))\n"
                    "Description: Test-only hprcc runtime resolver.\n"
                    "License: MIT\n"
                    "Encoding: UTF-8\n"
                )
                (package_source / "NAMESPACE").write_text(
                    "export(get_cluster, singularity_container, r_libs_site)\n"
                )
                (package_source / "R" / "runtime.R").write_text(implementation)
                library.mkdir()
                install = subprocess.run(
                    [r_executable, "CMD", "INSTALL", "-l", str(library), str(package_source)],
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(install.returncode, 0, install.stdout + install.stderr)

            stale_library = root / "stale-library"
            active_library = root / "active-library"
            install_hprcc(
                stale_library,
                "0.0.1",
                "get_cluster <- function() 'stale-runtime'\n"
                "singularity_container <- function() 'stale-container.sif'\n"
                "r_libs_site <- function() 'stale-library'\n",
            )
            install_hprcc(
                active_library,
                "0.0.2",
                "get_cluster <- function() Sys.getenv('TEST_HPRCC_CLUSTER')\n"
                "singularity_container <- function() Sys.getenv('TEST_HPRCC_CONTAINER')\n"
                "r_libs_site <- function() Sys.getenv('TEST_HPRCC_LIBRARY')\n",
            )

            launcher_text = (ROOT / "inst" / "extdata" / "k1-revised-acceptance-launch.sh").read_text()
            launcher_start_marker = "Rscript --vanilla -e '\n"
            launcher_end_marker = "\nexpected <-"
            self.assertIn(launcher_start_marker, launcher_text)
            launcher_start = launcher_text.index(launcher_start_marker) + len(launcher_start_marker)
            launcher_end = launcher_text.index(launcher_end_marker, launcher_start)
            launcher_resolver = launcher_text[launcher_start:launcher_end]
            resolver_variants = {
                "deployer preflight": (
                    resolver,
                    "cat('resolved\\t', cluster, '\\t', basename(container_path), '\\t', library_path, '\\n', sep = '')\n",
                ),
                "tracked launcher": (
                    launcher_resolver,
                    "cat('resolved\\t', hprcc::get_cluster(), '\\t', basename(Sys.getenv('SINGULARITY_CONTAINER')), '\\t', library_path, '\\n', sep = '')\n",
                ),
            }
            for resolver_name, (resolver_body, result_probe) in resolver_variants.items():
                resolver_script = root / (resolver_name.replace(" ", "-") + ".R")
                resolver_script.write_text(
                    "deployment_abort <- function(message, cause = NULL) stop(message)\n"
                    "bioconductor_version <- '3.22'\n"
                    "# Simulate a standard container whose base library shadows the active environment.\n"
                    ".libPaths(unique(c(Sys.getenv('TEST_HPRCC_STALE_LIBRARY'), Sys.getenv('TEST_HPRCC_ACTIVE_LIBRARY'), .libPaths())))\n"
                    + resolver_body
                    + "\n"
                    + result_probe
                )
                for cluster in ("apollo", "gemini"):
                    runtime_library = root / (resolver_name.replace(" ", "-") + "-runtime-" + cluster)
                    runtime_library.mkdir()
                    container = runtime_library / "rbiocverse_3.22.sif"
                    container.touch()
                    environment = os.environ.copy()
                    environment.update(
                        {
                            "R_LIBS_USER": str(stale_library),
                            "R_LIBS_SITE": str(active_library),
                            "TEST_HPRCC_STALE_LIBRARY": str(stale_library),
                            "TEST_HPRCC_ACTIVE_LIBRARY": str(active_library),
                            "TEST_HPRCC_CLUSTER": cluster,
                            "TEST_HPRCC_CONTAINER": str(container),
                            "TEST_HPRCC_LIBRARY": str(runtime_library),
                            "SLURM_JOB_ID": "12345",
                            "SINGULARITY_CONTAINER": str(container),
                        }
                    )
                    result = subprocess.run(
                        [rscript_executable, "--vanilla", str(resolver_script)],
                        text=True,
                        capture_output=True,
                        env=environment,
                        check=False,
                    )
                    self.assertEqual(
                        result.returncode,
                        0,
                        f"{resolver_name} ({cluster}) failed:\n{result.stderr}{result.stdout}",
                    )
                    self.assertIn(
                        f"resolved\t{cluster}\trbiocverse_3.22.sif\t{runtime_library}",
                        result.stdout,
                    )

    def test_public_proof_redacts_cluster_identifiers(self):
        proof = (ROOT / ".github" / "landing-proof" / "issue-249" / "deployment-dry-run.txt").read_text()
        self.assertNotIn("apollo", proof.lower())
        self.assertNotIn("gemini", proof.lower())
        self.assertNotIn("/shared/", proof)

    def test_issue_251_proof_records_the_hprcc_handoff(self):
        proof_root = ROOT / ".github" / "landing-proof" / "issue-251"
        proof = (proof_root / "deployment-dry-run.txt").read_text()
        manifest = (proof_root / "deployment-manifest.tsv").read_text()
        self.assertIn("active hprcc/rbiocverse Slurm session", proof)
        self.assertIn("hprcc/rbiocverse own runtime defaults", manifest)
        self.assertIn("session_boundary", manifest)
        self.assertNotIn("cluster-a", proof)
        self.assertNotIn("cluster-b", proof)
        self.assertNotIn("cluster-config.sh", proof + manifest)
        self.assertNotIn("/shared/", proof)


if __name__ == "__main__":
    unittest.main()
