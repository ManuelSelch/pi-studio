"""Validate portable Sonar coverage without Swift builds or credentials."""
from pathlib import Path
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent


class SonarCoverageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="pi-sonar-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "Packages/PiUI/Sources/PiUI/A&B.swift"
        self.source.parent.mkdir(parents=True)
        self.source.write_text("first\nsecond\nthird\n")
        self.report = self.root / "lcov.info"
        self.output = self.root / "coverage.xml"

    def convert(self, content):
        self.report.write_text(content)
        return subprocess.run(["python3", str(ROOT / "scripts/sonar-coverage.py"),
                               str(self.root), str(self.report), str(self.output)],
                              text=True, capture_output=True)

    def test_maps_counts_and_merges_duplicate_lines_with_portable_escaped_paths(self):
        result = self.convert(f"SF:{self.source}\nDA:1,0\nDA:2,3\nend_of_record\n"
                              f"SF:{self.source}\nDA:1,2\nDA:3,0\nend_of_record\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        tree = ET.parse(self.output).getroot()
        self.assertEqual(tree.attrib, {"version": "1"})
        self.assertEqual(tree.find("file").attrib["path"], "Packages/PiUI/Sources/PiUI/A&B.swift")
        self.assertEqual([line.attrib for line in tree.findall("file/lineToCover")], [
            {"lineNumber": "1", "covered": "true"},
            {"lineNumber": "2", "covered": "true"},
            {"lineNumber": "3", "covered": "false"},
        ])

    def test_filters_tests_dependencies_external_and_missing_files(self):
        paths = ["Packages/PiUI/Tests/Test.swift", ".build/checkouts/Dep.swift",
                 "Packages/PiUI/Sources/PiUI/Missing.swift", "../outside.swift"]
        content = "".join(f"SF:{self.root / path}\nDA:1,1\nend_of_record\n" for path in paths)
        result = self.convert(content + f"SF:{self.source}\nDA:1,1\nend_of_record\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(ET.parse(self.output).findall("file")), 1)

    def test_rejects_empty_coverage(self):
        result = self.convert("TN:\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No PiUI source coverage", result.stderr)

    def test_rejects_invalid_line_data(self):
        for data in ("0,1", "1,-1", "bogus,1"):
            with self.subTest(data=data):
                result = self.convert(f"SF:{self.source}\nDA:{data}\nend_of_record\n")
                self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
