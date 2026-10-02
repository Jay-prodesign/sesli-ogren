#!/usr/bin/env python3
from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from test_validate_voice_sample import valid as valid_sample  # noqa: E402
from validate_voice_benchmark import validate_benchmark  # noqa: E402


def candidate(key="candidate-01", start=1):
    rows = []
    for offset, item in enumerate("ABCDEFGHIJKL"):
        r = valid_sample()
        r["blind_sample_id"] = f"V{start + offset:02d}"
        r["hidden_provider_model_voice_key"] = key
        r["input_corpus_item"] = item
        rows.append(r)
    return rows


class VoiceBenchmarkValidatorTests(unittest.TestCase):
    def test_one_complete_candidate_passes(self):
        self.assertEqual(validate_benchmark(candidate()), [])

    def test_two_complete_candidates_pass(self):
        rows = candidate("candidate-01", 1) + candidate("candidate-02", 13)
        self.assertEqual(validate_benchmark(rows), [])

    def test_missing_corpus_item_fails(self):
        rows = candidate()[:-1]
        self.assertTrue(any("exactly 12 samples" in e or "corpus A-L" in e for e in validate_benchmark(rows)))

    def test_duplicate_blind_id_fails(self):
        rows = candidate()
        rows[1]["blind_sample_id"] = rows[0]["blind_sample_id"]
        self.assertTrue(any("duplicate blind_sample_id" in e for e in validate_benchmark(rows)))

    def test_mixed_format_fails(self):
        rows = candidate()
        rows[-1]["requested_format"] = "mp3"
        self.assertTrue(any("consistent requested format" in e for e in validate_benchmark(rows)))

    def test_mixed_quality_tier_fails(self):
        rows = candidate()
        rows[-1]["synthesis_mode_or_quality_tier"] = "other"
        self.assertTrue(any("consistent synthesis mode" in e for e in validate_benchmark(rows)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
