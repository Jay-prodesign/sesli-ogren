#!/usr/bin/env python3
import importlib.util
import json
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

    def test_parity_hash_is_identical_for_both_candidates(self):
        h = module.parity_hash(self.spec)
        self.assertEqual(len(h), 64)
        self.assertEqual(h, module.parity_hash(self.spec))

    def test_f0_prompts_share_locked_parity_and_hard_fails(self):
        d = module.build_f0_prompt(self.spec, "D")
        e = module.build_f0_prompt(self.spec, "E")
        for value in self.spec["parity"].values():
            self.assertIn(value, d)
            self.assertIn(value, e)
        for item in self.spec["shared_hard_fails"]:
            self.assertIn(item, d)
            self.assertIn(item, e)

    def test_f0_identity_stays_structurally_distinct(self):
        d = module.build_f0_prompt(self.spec, "D")
        e = module.build_f0_prompt(self.spec, "E")
        self.assertIn("interlaced knot body", d)
        self.assertIn("upright tilted body", e)
        self.assertIn("not loop-based", e)

    def test_f1_contains_exact_locked_states(self):
        for code in ("D", "E"):
            prompt = module.build_f1_prompt(self.spec, code)
            for state in self.spec["stages"]["F1"]["states"]:
                self.assertIn(state, prompt)


if __name__ == "__main__":
    unittest.main()
