"""Check released dependency requirements and fresh-checkout preparation without builds."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
EXPECTED = {"flux": "2.0.1", "router": "2.0.0"}
LOCAL_SDK_PATH = "../../.dependencies/pi-sdk-swift"


class ReleasedDependencyTests(unittest.TestCase):
    def test_piui_uses_exact_public_releases(self):
        result = subprocess.run(["swift", "package", "--package-path", str(ROOT / "Packages/PiUI"),
                                 "dump-package"], check=True, text=True, capture_output=True)
        dependencies = json.loads(result.stdout)["dependencies"]
        local = [dependency["fileSystem"][0] for dependency in dependencies if "fileSystem" in dependency]
        self.assertEqual([dependency["identity"] for dependency in local], ["pi-sdk-swift"])
        self.assertEqual(Path(local[0]["path"]).resolve(), (ROOT / "Packages/PiUI" / LOCAL_SDK_PATH).resolve())
        packages = {dependency["sourceControl"][0]["identity"]: dependency["sourceControl"][0]
                    for dependency in dependencies if "sourceControl" in dependency}
        for identity, version in EXPECTED.items():
            self.assertEqual(packages[identity]["requirement"], {"exact": [version]})
            self.assertTrue(packages[identity]["location"]["remote"][0]["urlString"].startswith("https://github.com/"))

    def test_xcode_uses_same_exact_public_releases(self):
        result = subprocess.run(["plutil", "-convert", "json", "-o", "-",
                                 str(ROOT / "pi-studio.xcodeproj/project.pbxproj")],
                                check=True, text=True, capture_output=True)
        objects = json.loads(result.stdout)["objects"].values()
        packages = {item["repositoryURL"].rsplit("/", 1)[-1].removesuffix(".git").lower(): item
                    for item in objects if item["isa"] == "XCRemoteSwiftPackageReference"}
        for identity, version in EXPECTED.items():
            self.assertEqual(packages[identity]["requirement"], {"kind": "exactVersion", "version": version})
        local = [item["relativePath"] for item in objects if item["isa"] == "XCLocalSwiftPackageReference"]
        self.assertEqual(set(local), {"Packages/PiUI", ".dependencies/pi-sdk-swift"})

    def test_prepare_links_local_sdk_and_resolves_remote_packages(self):
        with tempfile.TemporaryDirectory(prefix="pi-prepare-") as directory:
            root = Path(directory).resolve()
            sdk = root / "sdk"
            sdk.mkdir()
            (sdk / "Package.swift").write_text("// fixture")
            (root / "scripts").mkdir()
            (root / "bin").mkdir()
            for script in ("prepare.sh", "build-paths.sh"):
                shutil.copyfile(ROOT / "scripts" / script, root / "scripts" / script)
            swift = root / "bin/swift"
            swift.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$TEST_SWIFT_ARGS"\n')
            swift.chmod(0o755)
            result = subprocess.run(["bash", "scripts/prepare.sh"], cwd=root, text=True, capture_output=True,
                                    env={**os.environ, "PATH": str(root / "bin") + ":" + os.environ["PATH"],
                                         "PI_STUDIO_BUILD_ROOT": str(root / "products"),
                                         "PI_SDK_SWIFT_PATH": str(sdk),
                                         "TEST_SWIFT_ARGS": str(root / "args")})
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((root / ".dependencies/pi-sdk-swift").resolve(), sdk)
            self.assertEqual((root / "args").read_text().splitlines(),
                             ["package", "--package-path", str(root / "Packages/PiUI"),
                              "--scratch-path", str(root / "products/swiftpm"), "resolve"])

    def test_prepare_defaults_to_main_sdk_even_if_feature_worktree_exists(self):
        with tempfile.TemporaryDirectory(prefix="pi-prepare-default-") as directory:
            root = Path(directory).resolve()
            home = root / "home"
            main = home / "Documents/A_Personal/40 Projekte/47 Agents/Pi Agent/pi-sdk-swift"
            feature = home / ".worktrees/pi-sdk-swift/feat-close-session"
            for sdk in (main, feature):
                sdk.mkdir(parents=True)
                (sdk / "Package.swift").write_text("// fixture")
            (root / "scripts").mkdir()
            (root / "bin").mkdir()
            for script in ("prepare.sh", "build-paths.sh"):
                shutil.copyfile(ROOT / "scripts" / script, root / "scripts" / script)
            swift = root / "bin/swift"
            swift.write_text("#!/bin/bash\nexit 0\n")
            swift.chmod(0o755)
            env = {**os.environ, "HOME": str(home), "PATH": str(root / "bin") + ":" + os.environ["PATH"],
                   "PI_STUDIO_BUILD_ROOT": str(root / "products")}
            env.pop("PI_SDK_SWIFT_PATH", None)
            result = subprocess.run(["bash", "scripts/prepare.sh"], cwd=root, text=True, capture_output=True, env=env)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((root / ".dependencies/pi-sdk-swift").resolve(), main)

    def test_both_lockfiles_record_releases(self):
        for path in ("Packages/PiUI/Package.resolved",
                     "pi-studio.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"):
            with self.subTest(path=path):
                pins = {pin["identity"]: pin for pin in json.loads((ROOT / path).read_text())["pins"]}
                for identity, version in EXPECTED.items():
                    self.assertEqual(pins[identity]["state"]["version"], version)
                self.assertNotIn("pi-sdk-swift", pins)


if __name__ == "__main__":
    unittest.main()
