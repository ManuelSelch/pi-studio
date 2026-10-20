"""Exercise test destination selection without starting Xcode or Simulator."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
WORKTREE = hashlib.sha256(str(ROOT).encode()).hexdigest()[:12]
PRIVATE_NAME = f"PiStudio-{WORKTREE}"


class SimulatorIsolationTests(unittest.TestCase):
    def run_script(self, devices, override=None, platform="ios"):
        with tempfile.TemporaryDirectory(prefix="pi-simulator-test-") as directory:
            path = Path(directory)
            bin_path = path / "bin"
            bin_path.mkdir()
            simctl = bin_path / "xcrun"
            simctl.write_text("#!/bin/bash\necho \"$*\" >> \"$TEST_CALLS\"\n"
                               "if [[ \"$2\" == list ]]; then printf '%s' \"$TEST_DEVICES\"; else echo CREATED-UUID; fi\n")
            build = bin_path / "xcodebuild"
            build.write_text('#!/bin/bash\nprintf "%s\\n" "$@"\n')
            simctl.chmod(0o755)
            build.chmod(0o755)
            env = {**os.environ, "PATH": f"{bin_path}:{os.environ['PATH']}",
                   "PI_STUDIO_BUILD_ROOT": str(path / "products"), "TEST_CALLS": str(path / "calls"),
                   "TEST_DEVICES": json.dumps({"devices": {"runtime-26": devices}})}
            env.pop("PI_STUDIO_TEST_DESTINATION", None)
            if override:
                env["PI_STUDIO_TEST_DESTINATION"] = override
            result = subprocess.run(["bash", "scripts/test-app.sh", platform, "release"],
                                    cwd=ROOT, env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout, (path / "calls").read_text() if (path / "calls").exists() else ""

    def test_existing_worktree_simulator_is_used_by_id(self):
        output, calls = self.run_script([{"name": PRIVATE_NAME, "udid": "PRIVATE-UUID"},
                                         {"name": "iPhone 17", "udid": "SHARED-UUID"}])
        self.assertIn("platform=iOS Simulator,id=PRIVATE-UUID", output)
        self.assertNotIn("create", calls)

    def test_missing_private_simulator_is_created_in_installed_runtime(self):
        output, calls = self.run_script([{"name": "iPhone 17", "udid": "SHARED-UUID"}])
        self.assertIn("platform=iOS Simulator,id=CREATED-UUID", output)
        self.assertIn(f"simctl create {PRIVATE_NAME} com.apple.CoreSimulator.SimDeviceType.iPhone-17 runtime-26", calls)

    def test_explicit_override_does_not_query_or_create_simulators(self):
        output, calls = self.run_script([], "platform=iOS Simulator,id=OVERRIDE")
        self.assertIn("platform=iOS Simulator,id=OVERRIDE", output)
        self.assertEqual(calls, "")

    def test_macos_does_not_query_simulators(self):
        _, calls = self.run_script([], platform="macos")
        self.assertEqual(calls, "")


if __name__ == "__main__":
    unittest.main()
