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
        "schema_version": 2,
        "requirement": "R7-07A",
        "blind_sample_id": "V01",
        "provider_identity_hidden_from_listener": True,
        "hidden_provider_model_voice_key": "private-key-01",
        "execution_backend": "hosted_cloud",
        "platform": "server",
        "physical_device": False,
        "device_evidence_class": "not_applicable",
        "device_model": "provider-managed-runtime",
        "os_version": "provider-managed",
        "tts_engine_or_package": "provider-api",
        "provider_model_version": "provider/model/version",
        "voice_id_or_name": "voice-01",
        "language_locale": "tr-TR",
        "synthesis_mode_or_quality_tier": "benchmark",
        "voice_network_requirement": "network_required",
        "offline_tested": False,
        "offline_test_method": "not_applicable",
        "offline_result": "not_applicable",
        "audio_capture_or_generation_method": "provider response persisted to benchmark WAV",
        "metered_external_service_invoked": True,
        "input_corpus_version": "SESLI_OGREN_TURKISH_VOICE_IDENTITY_BENCHMARK_001-KL-FIXED",
        "input_corpus_item": "A",
        "input_text_sha256": "b" * 64,
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
        "cost": {
            "scope": "metered_external_provider_usage",
            "amount": 0.01,
            "unit": "USD",
            "evidence_basis": "provider usage export",
        },
        "operational_cost_notes": "Hosted benchmark; provider usage cost recorded separately from client/network overhead.",
        "cache_reuse_behavior": "disabled for benchmark",
        "raw_provider_metadata_location": "drive://metadata",
        "audio_file_location": "drive://audio/V01.wav",
        "audio_sha256": "a" * 64,
        "known_limitation": "None observed in generation metadata.",
    }


def valid_native():
    r = valid()
    r.update({
        "hidden_provider_model_voice_key": "ios-native-tr-voice-01",
        "execution_backend": "native_os",
        "platform": "ios",
        "physical_device": True,
        "device_evidence_class": "D1",
        "device_model": "physical-target-iphone",
        "os_version": "iOS benchmark build",
        "tts_engine_or_package": "AVSpeechSynthesizer",
        "provider_model_version": "system-voice-runtime",
        "voice_id_or_name": "installed-tr-TR-voice",
        "voice_network_requirement": "offline_capable",
        "offline_tested": True,
        "offline_test_method": "airplane mode with Wi-Fi and cellular disabled",
        "offline_result": "pass",
        "audio_capture_or_generation_method": "native synthesis-to-buffer benchmark capture",
        "metered_external_service_invoked": False,
        "streaming": False,
        "first_byte_latency_ms": None,
        "cost": {
            "scope": "metered_external_provider_usage",
            "amount": 0.0,
            "unit": "USD-provider-usage",
            "evidence_basis": "native OS synthesis with network-disabled pass and no external developer API call",
        },
        "operational_cost_notes": "Provider usage cost only; device compute/battery is evaluated separately.",
    })
    return r


class VoiceSampleValidatorTests(unittest.TestCase):
    def test_valid_sample_passes(self):
        self.assertEqual(validate(valid()), [])

    def test_valid_native_sample_passes(self):
        self.assertEqual(validate(valid_native()), [])

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

    def test_input_text_hash_required(self):
        r = valid()
        r["input_text_sha256"] = "abc"
        self.assertTrue(any("input_text_sha256" in e for e in validate(r)))

    def test_native_requires_physical_mobile_platform(self):
        r = valid_native()
        r["platform"] = "server"
        self.assertTrue(any("native_os samples" in e for e in validate(r)))

    def test_native_requires_physical_device_flag(self):
        r = valid_native()
        r["physical_device"] = False
        self.assertTrue(any("physical_device=true" in e for e in validate(r)))

    def test_native_requires_matching_device_class(self):
        r = valid_native()
        r["device_evidence_class"] = "D2"
        self.assertTrue(any("native iOS evidence must bind to D1" in e for e in validate(r)))

    def test_native_requires_offline_test(self):
        r = valid_native()
        r["offline_tested"] = False
        r["offline_test_method"] = "not_applicable"
        r["offline_result"] = "not_applicable"
        self.assertTrue(any("real offline test" in e for e in validate(r)))

    def test_native_requires_offline_test_method(self):
        r = valid_native()
        r["offline_test_method"] = "FILL"
        self.assertTrue(any("offline_test_method" in e for e in validate(r)))

    def test_native_cannot_invoke_metered_external_service(self):
        r = valid_native()
        r["metered_external_service_invoked"] = True
        self.assertTrue(any("metered external service" in e for e in validate(r)))

    def test_zero_cost_claim_requires_no_metered_external_service(self):
        r = valid()
        r["metered_external_service_invoked"] = False
        r["cost"] = {
            "scope": "metered_external_provider_usage",
            "amount": 1.0,
            "unit": "USD",
            "evidence_basis": "test",
        }
        self.assertTrue(any("cost.amount must be 0" in e for e in validate(r)))

    def test_cost_scope_is_explicit(self):
        r = valid()
        r["cost"]["scope"] = "total_operational_cost"
        self.assertTrue(any("cost.scope" in e for e in validate(r)))

    def test_cost_evidence_basis_required(self):
        r = valid()
        r["cost"]["evidence_basis"] = "FILL"
        self.assertTrue(any("cost.evidence_basis" in e for e in validate(r)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
