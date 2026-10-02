#!/usr/bin/env python3
from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from validate_device_evidence import validate  # noqa: E402


SHA = "ec84e603a67a8fd286e5c57c2a808d62d5c5cd6d"


def valid_report():
    scenarios = []
    for i in range(1, 12):
        item = {"id": f"T{i}", "result": "FUNCTIONAL_PASS"}
        if i == 11:
            item.update({
                "cycles": 30,
                "live_controllers_before_after": [4, 4],
                "rss_samples_bytes": [100, 101, 102, 102, 103, 103, 103],
            })
        scenarios.append(item)
    return {
        "proof": "ROUND_7_P1_RUNTIME_PROOF_SPEC_001",
        "git_sha": SHA,
        "build_mode": "profile",
        "decision_grade": "ONLY_IF_PHYSICAL_DEVICE",
        "functional_result": "PASS",
        "scenarios": scenarios,
    }


def valid_evidence():
    return {
        "schema_version": 1,
        "evidence_id": "R7-06-D1-001",
        "requirement": "R7-06",
        "device_class": "D1",
        "exact_model": "iPhone test model",
        "os_version": "iOS test version",
        "refresh_rate_hz": 120,
        "build_sha": SHA,
        "build_checksum_sha256": "a" * 64,
        "flutter_version": "3.47.5",
        "test_mode": "PROFILE",
        "raw_timeline_location": "build/p1_timeline.timeline_summary.json",
        "raw_p1_report_location": "build/p1_report.json",
        "cold_start_ms": [300, 290, 305],
        "memory_bytes": {"baseline": 1, "world": 2, "post_t11": 2},
        "memory_unbounded_growth": False,
        "visible_repeated_jank": False,
        "thermal_blocking_issue": False,
        "thermal_battery_observation": "No warning observed in bounded test.",
        "pause_resume": {"teach": "PASS", "challenge": "PASS"},
        "fallbacks": {
            "reduced_motion": "PASS",
            "audio_unavailable": "PASS",
            "companion_asset_failure": "PASS",
            "world_asset_failure": "PASS",
            "content_tier": "PASS",
        },
        "accessibility": {
            "screen_reader": "VoiceOver",
            "result": "PASS",
            "largest_text": "PASS",
            "focus_order": "PASS",
            "announcements": "PASS",
        },
        "overall_result": "PASS",
        "known_limitation": "None for fixture.",
        "reviewer": "QA",
    }


class DeviceEvidenceValidatorTests(unittest.TestCase):
    def test_valid_d1_passes(self):
        self.assertEqual(validate(valid_report(), valid_evidence()), [])

    def test_sha_mismatch_fails(self):
        evidence = valid_evidence()
        evidence["build_sha"] = "b" * 40
        self.assertTrue(any("report.git_sha" in e for e in validate(valid_report(), evidence)))

    def test_missing_cold_start_fails(self):
        evidence = valid_evidence()
        evidence["cold_start_ms"] = [300, 290]
        self.assertTrue(any("cold_start_ms" in e for e in validate(valid_report(), evidence)))

    def test_short_soak_fails_for_pass(self):
        report = valid_report()
        report["scenarios"][-1]["cycles"] = 10
        self.assertTrue(any("30 soak cycles" in e for e in validate(report, valid_evidence())))

    def test_pass_with_jank_fails(self):
        evidence = valid_evidence()
        evidence["visible_repeated_jank"] = True
        self.assertTrue(any("repeated visible jank" in e for e in validate(valid_report(), evidence)))

    def test_d1_requires_voiceover(self):
        evidence = valid_evidence()
        evidence["accessibility"]["screen_reader"] = "TalkBack"
        self.assertTrue(any("D1 must record VoiceOver" in e for e in validate(valid_report(), evidence)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
