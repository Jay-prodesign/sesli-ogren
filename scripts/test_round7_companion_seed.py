#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).with_name("round7_companion_seed.py")
spec = importlib.util.spec_from_file_location("round7_companion_seed", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)


class SeedTests(unittest.TestCase):
    def test_all_variants_generate(self):
        for candidate in ("D", "E"):
            for variant in (1, 2, 3):
                svg = module.seed_svg(candidate, variant)
                self.assertIn("<svg", svg)
                self.assertIn("non-final-art", svg)
                self.assertNotIn("<text", svg)
                self.assertNotIn("<image", svg)
                self.assertNotIn("<filter", svg)
                self.assertNotIn("<circle", svg)
                self.assertNotIn("<ellipse", svg)

    def test_d_uses_interlaced_stroked_paths(self):
        svg = module.seed_svg("D", 1)
        self.assertGreaterEqual(svg.count("<path"), 4)
        self.assertIn("stroke-linecap=\"round\"", svg)
        self.assertIn("fill=\"none\"", svg)

    def test_e_uses_upright_filled_facets(self):
        svg = module.seed_svg("E", 1)
        self.assertGreaterEqual(svg.count("<path"), 3)
        self.assertIn('fill="#161616"', svg)
        self.assertNotIn("stroke-linecap", svg)

    def test_candidates_are_structurally_distinct(self):
        self.assertNotEqual(module.seed_svg("D", 2), module.seed_svg("E", 2))


if __name__ == "__main__":
    unittest.main()
