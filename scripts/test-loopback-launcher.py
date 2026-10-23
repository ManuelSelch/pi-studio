"""Verify the fixture's stdout handshake without launching Xcode or Simulator."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class LoopbackLauncherTests(unittest.TestCase):
    def test_uses_owned_workspace_announced_on_stdout(self):
        with tempfile.TemporaryDirectory(prefix="pi-loopback-script-") as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            (root / "bin").mkdir()
            (root / "server").mkdir()
            shutil.copyfile(ROOT / "scripts/test-simulator-loopback.sh", root / "scripts/test-simulator-loopback.sh")
            app = root / "scripts/test-app.sh"
            app.write_text('#!/bin/bash\nset -eu\n[[ "$TEST_RUNNER_PI_STUDIO_TEST_ENDPOINT" == ws://127.0.0.1:12345/ws ]]\n[[ -d "$TEST_RUNNER_PI_STUDIO_TEST_PROJECT" ]]\nprintf success\n')
            node = root / "bin/node"
            node.write_text('#!/usr/bin/env python3\nimport json, os, pathlib, signal, sys, tempfile, time\n'
                            'assert sys.argv[1:] == ["--import", "tsx", "test/swift-integration/fixtures/loopback-server.ts"], sys.argv\n'
                            'p = pathlib.Path(tempfile.mkdtemp(prefix="pi-swift-fixture-", dir=os.environ["FIXTURE_PARENT"]))\n'
                            'def stop(*_):\n (p/"cleanup.json").write_text(json.dumps({"created":1,"retained":1,"closed":1})); sys.exit(0)\n'
                            'signal.signal(signal.SIGTERM, stop)\n'
                            'print("PI_FIXTURE_READY " + json.dumps({"directory":str(p),"endpoint":"ws://127.0.0.1:12345/ws"}), flush=True)\n'
                            'while True: time.sleep(0.1)\n')
            node.chmod(0o755)
            result = subprocess.run(["bash", "scripts/test-simulator-loopback.sh", "ios"], cwd=root,
                                    env={**os.environ, "PATH": str(root / "bin") + ":" + os.environ["PATH"],
                                         "PI_CHAT_CHECKOUT": str(root / "server"), "FIXTURE_PARENT": str(root)},
                                    text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("success", result.stdout)
            self.assertFalse(list(root.glob("pi-swift-fixture-*")), "Successful fixture workspace must be removed")


if __name__ == "__main__":
    unittest.main()
