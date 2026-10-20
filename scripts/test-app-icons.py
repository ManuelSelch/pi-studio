#!/usr/bin/env python3
"""Validate native app icon slots and PNG dimensions without image dependencies."""
import json
import struct
import unittest
from pathlib import Path


ICON_SET = Path(__file__).resolve().parents[1] / "pi-studio/Assets.xcassets/AppIcon.appiconset"


class AppIconTests(unittest.TestCase):
    def test_platform_slots_have_correct_pngs(self):
        images = json.loads((ICON_SET / "Contents.json").read_text())["images"]
        expected = {("universal", "1024x1024", "1x")}
        expected.update(("mac", f"{size}x{size}", scale)
                        for size in (16, 32, 128, 256, 512)
                        for scale in ("1x", "2x"))
        actual = set()
        for image in images:
            with self.subTest(image=image):
                slot = (image["idiom"], image["size"], image.get("scale", "1x"))
                self.assertNotIn(slot, actual)
                actual.add(slot)
                png = (ICON_SET / image["filename"]).read_bytes()
                self.assertEqual(png[:8], b"\x89PNG\r\n\x1a\n")
                pixels = int(image["size"].split("x")[0]) * int(slot[2][0])
                self.assertEqual(struct.unpack(">II", png[16:24]), (pixels, pixels))
                if image["idiom"] == "universal":
                    self.assertEqual(image["platform"], "ios")
                    self.assertEqual(png[25], 2, "iOS icon must be opaque RGB")
        self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()
