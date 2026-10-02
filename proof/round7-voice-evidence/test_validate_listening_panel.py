#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from validate_listening_panel import DIMENSIONS, validate  # noqa: E402


def ratings(value=4):
    return {k: value for k in DIMENSIONS}


def valid():
    return {
        "schema_version": 1,
        "requirement": "R7-07A",
        "panel_id": "R7-07A-PANEL-001",
        "provider_identity_exposed_to_listeners": False,
        "playback_order_randomized": True,
        "blind_sample_ids": ["V01", "V02"],
        "participants": [
            {
                "participant_code": "P01",
                "consent_recorded": True,
                "turkish_fluency": "native",
                "listening_device": "headphones",
                "sample_order": ["V02", "V01"],
                "ratings": {"V01": ratings(), "V02": ratings()},
                "critical_defects": {"V01": [], "V02": []},
            }
        ],
        "automated_winner_or_ranking": False,
    }


class ListeningPanelValidatorTests(unittest.TestCase):
    def test_valid_panel_passes(self):
        self.assertEqual(validate(valid()), [])

    def test_provider_identity_must_remain_blind(self):
        p = valid()
        p["provider_identity_exposed_to_listeners"] = True
        self.assertTrue(any("exposed_to_listeners" in e for e in validate(p)))

    def test_native_or_near_native_required(self):
        p = valid()
        p["participants"][0]["turkish_fluency"] = "basic"
        self.assertTrue(any("turkish_fluency" in e for e in validate(p)))

    def test_all_dimensions_required(self):
        p = valid()
        del p["participants"][0]["ratings"]["V01"]["warmth"]
        self.assertTrue(any("canonical dimensions" in e for e in validate(p)))

    def test_scores_are_one_to_five(self):
        p = valid()
        p["participants"][0]["ratings"]["V01"]["warmth"] = 6
        self.assertTrue(any("integer 1-5" in e for e in validate(p)))

    def test_no_automated_ranking(self):
        p = valid()
        p["automated_winner_or_ranking"] = True
        self.assertTrue(any("automated_winner_or_ranking" in e for e in validate(p)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
