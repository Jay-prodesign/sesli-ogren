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

    def test_reference_locked_strategy_is_required(self):
        self.assertEqual(self.spec["production_mode"]["strategy"], "reference_locked_edit")
        self.assertEqual(self.spec["seed_control"]["variants_per_candidate"], 3)

    def test_f0_requires_attached_seed_and_topology_lock(self):
        for code in ("D", "E"):
            prompt = module.build_f0_prompt(self.spec, code)
            self.assertIn("ATTACHED geometry control seed", prompt)
            self.assertIn("PRESERVING its outer silhouette", prompt)
            self.assertIn("do not convert structural apertures into eyes", prompt)
            self.assertIn("output ONE isolated candidate", prompt)

    def test_f1_requires_approved_f0_reference(self):
        for code in ("D", "E"):
            prompt = module.build_f1_prompt(self.spec, code)
            self.assertIn("ATTACHED approved F0 canonical form", prompt)
            self.assertIn("Do not redesign the character", prompt)



if __name__ == "__main__":
    unittest.main()
