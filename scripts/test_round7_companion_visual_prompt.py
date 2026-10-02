#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).with_name("round7_companion_visual_prompt.py")
spec = importlib.util.spec_from_file_location("round7_visual_prompt", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)


class Round7CompanionVisualPromptTests(unittest.TestCase):
    def setUp(self):
        self.spec = module.load_spec()

    def test_locked_spec_lints(self):
        self.assertEqual(module.lint_spec(self.spec), [])

    def test_design_authority_is_locked(self):
        self.assertEqual(
            self.spec["production_mode"]["strategy"],
            "design_plan_locked_generation",
        )
        self.assertEqual(
            self.spec["production_mode"]["design_authority"],
            "ROUND_7_CURRENT_FINALIST_REBUILD_BRIEF_001",
        )

    def test_parity_hash_is_stable(self):
        h = module.parity_hash(self.spec)
        self.assertEqual(len(h), 64)
        self.assertEqual(h, module.parity_hash(self.spec))

    def test_f0_preserves_character_identity_and_rejects_tool_driven_redesign(self):
        for code in ("D", "E"):
            prompt = module.build_f0_prompt(self.spec, code)
            self.assertIn("living, responsive learning character", prompt)
            self.assertIn("Tool limitations are not design input", prompt)
            self.assertIn("One candidate only", prompt)

    def test_candidate_directions_remain_distinct(self):
        d = module.build_f0_prompt(self.spec, "D")
        e = module.build_f0_prompt(self.spec, "E")
        self.assertIn("interlaced knot body", d)
        self.assertIn("upright tilted body", e)
        self.assertIn("not loop-based", e)

    def test_f1_contains_exact_states(self):
        for code in ("D", "E"):
            prompt = module.build_f1_prompt(self.spec, code)
            for state in self.spec["stages"]["F1"]["states"]:
                self.assertIn(state, prompt)


if __name__ == "__main__":
    unittest.main()
