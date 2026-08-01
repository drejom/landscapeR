import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
BUILD_SCRIPT = REPO_ROOT / "scripts" / "build-pkgdown-site.sh"


class PkgdownStackBalanceGuardTests(unittest.TestCase):
    def run_with_fake_rscript(self, output: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as temp_dir:
            fake_rscript = Path(temp_dir) / "Rscript"
            fake_rscript.write_text(
                "#!/usr/bin/env bash\n"
                f"printf '%s\\n' {output!r}\n",
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


if __name__ == "__main__":
    unittest.main()
