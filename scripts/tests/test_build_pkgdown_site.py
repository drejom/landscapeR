import os
import stat
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
BUILD_SCRIPT = REPO_ROOT / "scripts" / "build-pkgdown-site.sh"


class PkgdownStackBalanceGuardTests(unittest.TestCase):
    def run_with_fake_rscript(
        self, output: str, exit_code: int = 0
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as temp_dir:
            fake_rscript = Path(temp_dir) / "Rscript"
            fake_rscript.write_text(
                "#!/usr/bin/env bash\n"
                f"printf '%s\\n' {output!r}\n"
                f"exit {exit_code}\n",
                encoding="utf-8",
            )
            fake_rscript.chmod(fake_rscript.stat().st_mode | stat.S_IXUSR)
            env = os.environ.copy()
            env["PATH"] = f"{temp_dir}{os.pathsep}{env['PATH']}"
            return subprocess.run(
                ["bash", str(BUILD_SCRIPT)],
                cwd=REPO_ROOT,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

    def test_clean_build_output_passes(self):
        result = self.run_with_fake_rscript("site complete")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("completed without protection-stack imbalance", result.stdout)

    def test_stack_imbalance_output_fails(self):
        result = self.run_with_fake_rscript(
            "Warning: stack imbalance in 'vapply', 76 then 78"
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("protection-stack imbalance detected", result.stderr)

    def test_underlying_build_failure_is_propagated(self):
        result = self.run_with_fake_rscript("installation failed", exit_code=7)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Site build failed", result.stderr)

    def test_concurrent_builds_use_distinct_logs(self):
        existing_logs = set((REPO_ROOT / ".scratch").glob("pkgdown-build.*"))
        with tempfile.TemporaryDirectory() as temp_dir:
            fake_rscript = Path(temp_dir) / "Rscript"
            fake_rscript.write_text(
                "#!/usr/bin/env bash\n"
                "sleep 1\n"
                "printf '%s\\n' 'site complete'\n",
                encoding="utf-8",
            )
            fake_rscript.chmod(fake_rscript.stat().st_mode | stat.S_IXUSR)
            env = os.environ.copy()
            env["PATH"] = f"{temp_dir}{os.pathsep}{env['PATH']}"
            processes = [
                subprocess.Popen(
                    ["bash", str(BUILD_SCRIPT)],
                    cwd=REPO_ROOT,
                    env=env,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                for _ in range(2)
            ]
            deadline = time.monotonic() + 2
            active_logs = set()
            while time.monotonic() < deadline:
                active_logs = (
                    set((REPO_ROOT / ".scratch").glob("pkgdown-build.*"))
                    - existing_logs
                )
                if len(active_logs) == 2:
                    break
                time.sleep(0.05)
            results = [process.communicate() for process in processes]

        self.assertEqual(
            len(active_logs), 2, f"expected two distinct active logs, got {active_logs}"
        )
        for process, (stdout, stderr) in zip(processes, results):
            self.assertEqual(process.returncode, 0, stderr)
            self.assertIn("completed without protection-stack imbalance", stdout)
        remaining_logs = (
            set((REPO_ROOT / ".scratch").glob("pkgdown-build.*")) - existing_logs
        )
        self.assertEqual(remaining_logs, set())


if __name__ == "__main__":
    unittest.main()
