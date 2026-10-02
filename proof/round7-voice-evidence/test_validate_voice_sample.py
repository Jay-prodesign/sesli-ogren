#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from validate_voice_sample import validate  # noqa: E402


def valid():
    return {
        "schema_version": 1,
        "requirement": "R7-07A",
        "blind_sample_id": "V01",
        "provider_identity_hidden_from_listener": True,
        "hidden_provider_model_voice_key": "private-key-01",
        "provider_model_version": "provider/model/version",
        "voice_id_or_name": "voice-01",
        "language_locale": "tr-TR",
        "synthesis_mode_or_quality_tier": "benchmark",
        "input_corpus_item": "A",
        "input_character_count": 120,
        "input_bytes": 134,
        "requested_format": "wav/24000/pcm16",
        "actual_duration_ms": 5500,
        "generation_started_at": "2026-10-02T12:00:00+03:00",
        "streaming": True,
        "first_byte_latency_ms": 250,
        "full_completion_latency_ms": 900,
        "retries_count": 0,
        "errors": [],
        "cost": {"amount": 0.0, "unit": "credits"},
        "cache_reuse_behavior": "disabled for benchmark",
        "raw_provider_metadata_location": "drive://metadata",
        "audio_file_location": "drive://audio/V01.wav",
        "audio_sha256": "a" * 64,
        "known_limitation": "None observed in generation metadata.",
    }


class VoiceSampleValidatorTests(unittest.TestCase):
    def test_valid_sample_passes(self):
        self.assertEqual(validate(valid()), [])

    def test_blind_identity_must_be_hidden(self):
        r = valid()
        r["provider_identity_hidden_from_listener"] = False
        self.assertTrue(any("hidden_from_listener" in e for e in validate(r)))

    def test_turkish_locale_required(self):
        r = valid()
        r["language_locale"] = "en-US"
        self.assertTrue(any("Turkish" in e for e in validate(r)))

    def test_streaming_requires_first_byte_latency(self):
        r = valid()
        r["first_byte_latency_ms"] = None
        self.assertTrue(any("first_byte" in e for e in validate(r)))

    def test_timestamp_requires_timezone(self):
        r = valid()
        r["generation_started_at"] = "2026-10-02T12:00:00"
        self.assertTrue(any("timezone" in e for e in validate(r)))

    def test_checksum_required(self):
        r = valid()
        r["audio_sha256"] = "abc"
        self.assertTrue(any("audio_sha256" in e for e in validate(r)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
