#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest
SCRIPT=Path(__file__).with_name("round7_companion_visual_prompt.py")
sp=importlib.util.spec_from_file_location("r7",SCRIPT); m=importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
class Tests(unittest.TestCase):
 def setUp(self): self.s=m.load_spec()
 def test_lint(self): self.assertEqual(m.lint_spec(self.s),[])
 def test_animation_first_f0(self):
  p=m.build_f0_prompt(self.s,"D"); self.assertIn("MOTION ANATOMY PROOF",p); self.assertIn("animation-ready",p)
 def test_f0_runtime_fit_is_required(self):
  self.assertIn("runtime_smoke",self.s["stages"]["F0"])
  self.assertIn("actual CompanionRenderer integration",self.s["acceptance_levels"]["PRODUCTION_ASSET_PASS"])
 def test_asset_lifecycle_and_master_lock(self):
  life=self.s["asset_lifecycle"]
  self.assertIn("canonical master",life["flow"])
  self.assertIn("isolated reusable source asset",life["flow"])
  self.assertIn("Derivatives may not silently supersede it",life["master_rule"])
 def test_source_pass_is_not_production_pass(self):
  self.assertIn("SOURCE_VISUAL_PASS",self.s["acceptance_levels"])
  self.assertIn("PRODUCTION_ASSET_PASS",self.s["acceptance_levels"])
  self.assertNotEqual(self.s["acceptance_levels"]["SOURCE_VISUAL_PASS"],self.s["acceptance_levels"]["PRODUCTION_ASSET_PASS"])
 def test_semantic_state_is_not_visual_authority(self):
  fw=self.s["semantic_authority_firewall"]
  self.assertIn("LearnerState",fw["forbidden_visual_authority"])
  self.assertIn("LearnerEvidence",fw["forbidden_visual_authority"])
 def test_jury_loop_locked(self):
  self.assertEqual(self.s["production_mode"]["strategy"],"design_plan_locked_generate_jury_repair_integrate_loop")
 def test_known_rejected_failure_classes_locked(self):
  self.assertIn("ROBOT_FACE_DRIFT",self.s["failure_codes"]); self.assertIn("ABSTRACT_LOGO_OBJECT_DRIFT",self.s["failure_codes"])
  self.assertIn("RUNTIME_CONTEXT_FAIL",self.s["failure_codes"])
 def test_repair_is_failure_specific_and_preserves_passes(self):
  p=m.build_repair_prompt(self.s,"D",["ABSTRACT_LOGO_OBJECT_DRIFT","WEAK_ATTENTION_SYSTEM"],["interlaced silhouette passes"])
  self.assertIn("ABSTRACT_LOGO_OBJECT_DRIFT",p); self.assertIn("WEAK_ATTENTION_SYSTEM",p); self.assertIn("interlaced silhouette passes",p); self.assertIn("DO NOT START A NEW CONCEPT",p)
 def test_unknown_failure_rejected(self):
  with self.assertRaises(ValueError): m.build_repair_prompt(self.s,"D",["MAKE_IT_CUTER"],[])
if __name__=="__main__": unittest.main()
