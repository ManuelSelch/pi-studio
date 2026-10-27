"""Convert SwiftPM LLVM LCOV line counts to portable Sonar generic coverage."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def convert(root, report, output):
    root = root.resolve()
    sources = root / "Packages/PiUI/Sources/PiUI"
    files = {}
    current = None
    for record in report.read_text().splitlines():
        if record.startswith("SF:"):
            path = Path(record[3:])
            path = (root / path).resolve()
            current = (path.relative_to(root).as_posix()
                       if path.is_relative_to(sources) and path.is_file() else None)
        elif record == "end_of_record":
            current = None
        elif record.startswith("DA:") and current is not None:
            line, count = map(int, record[3:].split(",")[:2])
            if line <= 0 or count < 0:
                raise ValueError("Invalid LCOV line/count")
            lines = files.setdefault(current, {})
            lines[line] = lines.get(line, False) or count > 0

    if not files:
        raise ValueError("No PiUI source coverage found")
    coverage = ET.Element("coverage", version="1")
    for path, lines in sorted(files.items()):
        file = ET.SubElement(coverage, "file", path=path)
        for line, covered in sorted(lines.items()):
            ET.SubElement(file, "lineToCover", lineNumber=str(line), covered=str(covered).lower())
    output.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(coverage)
    ET.ElementTree(coverage).write(output, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("Usage: sonar-coverage.py PROJECT_ROOT LCOV_REPORT OUTPUT_XML")
    convert(*(Path(arg) for arg in sys.argv[1:]))
