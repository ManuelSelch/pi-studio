"""Check released dependency requirements and fresh-checkout preparation without builds."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
EXPECTED = {"pi-sdk-swift": "0.1.0", "flux": "2.0.1"}


class ReleasedDependencyTests(unittest.TestCase):
    def test_piui_uses_exact_public_releases(self):
        result = subprocess.run(["swift", "package", "--package-path", str(ROOT / "Packages/PiUI"),
                                 "dump-package"], check=True, text=True, capture_output=True)
        dependencies = json.loads(result.stdout)["dependencies"]
        local = [dependency["fileSystem"][0] for dependency in dependencies if "fileSystem" in dependency]
        self.assertEqual(len(local), 1)
        self.assertEqual(Path(local[0]["path"]), ROOT / ".dependencies/router")
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
        self.assertEqual(local, ["Packages/PiUI"])

    def test_prepare_links_only_the_local_router(self):
        self.check_prepare("valid")

    def test_prepare_rejects_missing_router_before_resolution(self):
        self.check_prepare("missing")

    def test_prepare_does_not_replace_a_real_dependency_directory(self):
        self.check_prepare("occupied")

    def check_prepare(self, mode):
        with tempfile.TemporaryDirectory(prefix="pi-prepare-") as directory:
            root = Path(directory).resolve()
            (root / "scripts").mkdir()
            (root / "bin").mkdir()
            for script in ("prepare.sh", "build-paths.sh"):
                shutil.copyfile(ROOT / "scripts" / script, root / "scripts" / script)
            swift = root / "bin/swift"
            swift.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$TEST_SWIFT_ARGS"\n')
            swift.chmod(0o755)
            router = root / "local Router"
            if mode != "missing":
                router.mkdir()
                (router / "Package.swift").write_text("// local Router fixture\n")
            if mode == "occupied":
                (root / ".dependencies/router").mkdir(parents=True)
            result = subprocess.run(["bash", "scripts/prepare.sh"], cwd=root, text=True, capture_output=True,
                                    env={**os.environ, "PATH": str(root / "bin") + ":" + os.environ["PATH"],
                                         "PI_SDK_PATH": str(root / "missing-sdk"),
                                         "PI_FLUX_PATH": str(root / "missing-flux"),
                                         "PI_ROUTER_PATH": str(router),
                                         "PI_STUDIO_BUILD_ROOT": str(root / "products"),
                                         "TEST_SWIFT_ARGS": str(root / "args")})
            if mode != "valid":
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("PI_ROUTER_PATH" if mode == "missing" else "Refusing", result.stderr)
                self.assertFalse((root / "args").exists())
                if mode == "occupied":
                    self.assertFalse((root / ".dependencies/router").is_symlink())
                return
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((root / ".dependencies/router").is_symlink())
            self.assertEqual((root / ".dependencies/router").resolve(), router)
            self.assertEqual([p.name for p in (root / ".dependencies").iterdir()], ["router"])
            self.assertEqual((root / "args").read_text().splitlines(),
                             ["package", "--package-path", str(root / "Packages/PiUI"),
                              "--scratch-path", str(root / "products/swiftpm"), "resolve"])

    def test_both_lockfiles_record_releases(self):
        for path in ("Packages/PiUI/Package.resolved",
                     "pi-studio.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"):
            with self.subTest(path=path):
                pins = {pin["identity"]: pin for pin in json.loads((ROOT / path).read_text())["pins"]}
                for identity, version in EXPECTED.items():
                    self.assertEqual(pins[identity]["state"]["version"], version)


if __name__ == "__main__":
    unittest.main()
