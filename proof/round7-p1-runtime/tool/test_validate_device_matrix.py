#!/usr/bin/env python3
from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from validate_device_matrix import validate_matrix  # noqa: E402

SHA = "ec84e603a67a8fd286e5c57c2a808d62d5c5cd6d"


def record(device_class: str, model: str, screen_reader: str, a11y_result: str = "PASS"):
    return {
        "device_class": device_class,
        "exact_model": model,
        "build_sha": SHA,
        "test_mode": "PROFILE",
        "overall_result": "PASS",
        "accessibility": {
            "screen_reader": screen_reader,
            "result": a11y_result,
        },
    }


def valid_matrix():
    return [
        record("D1", "iPhone fixture", "VoiceOver"),
        record("D2", "Android mid fixture", "TalkBack"),
        record("D3", "Android low fixture", "NOT_RUN", "NOT_RUN"),
    ]


class MatrixValidatorTests(unittest.TestCase):
    def test_valid_matrix_passes(self):
        self.assertEqual(validate_matrix(valid_matrix()), [])

    def test_missing_class_fails(self):
        rows = valid_matrix()[:2]
        self.assertTrue(any("exactly three" in e or "exactly one each" in e for e in validate_matrix(rows)))

    def test_mixed_build_sha_fails(self):
        rows = valid_matrix()
        rows[2]["build_sha"] = "b" * 40
        self.assertTrue(any("same build_sha" in e for e in validate_matrix(rows)))

    def test_missing_android_talkback_fails(self):
        rows = valid_matrix()
        rows[1]["accessibility"] = {"screen_reader": "NOT_RUN", "result": "NOT_RUN"}
        self.assertTrue(any("TalkBack" in e for e in validate_matrix(rows)))

    def test_d1_voiceover_required(self):
        rows = valid_matrix()
        rows[0]["accessibility"] = {"screen_reader": "NOT_RUN", "result": "NOT_RUN"}
        self.assertTrue(any("VoiceOver" in e for e in validate_matrix(rows)))

    def test_all_devices_must_pass(self):
        rows = valid_matrix()
        rows[2]["overall_result"] = "CHANGE_REQUIRED"
        self.assertTrue(any("all PASS" in e for e in validate_matrix(rows)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
