#!/usr/bin/env python3
"""Fail-closed structural validation for one R7-07A Turkish voice sample record.

This validates provenance/completeness only. It does not assess audio quality,
select a provider/voice, authorize spend/credentials, or grant R7-07 PASS.
Standard library only.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

BLIND_ID = re.compile(r"^V[0-9]{2,}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
CORPUS_ITEMS = set("ABCDEFGHIJKL")
EXECUTION_BACKENDS = {"native_os", "self_hosted", "hosted_cloud"}
PLATFORMS = {"ios", "android", "server", "desktop", "other"}
DEVICE_EVIDENCE_CLASSES = {"D1", "D2", "D3", "not_applicable"}
OFFLINE_RESULTS = {"pass", "fail", "not_applicable"}
NETWORK_REQUIREMENTS = {"offline_capable", "network_required", "unknown_not_exposed"}


def _load(path: str) -> dict[str, Any]:
    with Path(path).open("r", encoding="utf-8") as fh:
        value = json.load(fh)
    if not isinstance(value, dict):
        raise ValueError(f"{path}: top-level JSON must be an object")
    return value


def _nonblank(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip()) and value.strip().upper() not in {
        "FILL", "TBD", "TODO", "UNKNOWN", "NOT_RUN"
    }


def _positive(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value > 0


def _nonnegative(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value >= 0


def _iso_with_timezone(value: Any) -> bool:
    if not _nonblank(value):
        return False
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return False
    return parsed.tzinfo is not None


def validate(record: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    def require(ok: bool, message: str) -> None:
        if not ok:
            errors.append(message)

    require(record.get("schema_version") == 2, "schema_version must be 2")
    require(record.get("requirement") == "R7-07A", "requirement must be R7-07A")

    blind_id = record.get("blind_sample_id")
    require(isinstance(blind_id, str) and bool(BLIND_ID.fullmatch(blind_id)),
            "blind_sample_id must match V01, V02, ...")
    require(record.get("provider_identity_hidden_from_listener") is True,
            "provider_identity_hidden_from_listener must be true")

    for key in (
        "hidden_provider_model_voice_key",
        "device_model",
        "os_version",
        "tts_engine_or_package",
        "provider_model_version",
        "voice_id_or_name",
        "synthesis_mode_or_quality_tier",
        "audio_capture_or_generation_method",
        "operational_cost_notes",
        "requested_format",
        "cache_reuse_behavior",
        "raw_provider_metadata_location",
        "audio_file_location",
        "known_limitation",
    ):
        require(_nonblank(record.get(key)), f"{key} must be recorded")

    backend = record.get("execution_backend")
    require(backend in EXECUTION_BACKENDS,
            f"execution_backend must be one of {sorted(EXECUTION_BACKENDS)}")

    platform = record.get("platform")
    require(platform in PLATFORMS, f"platform must be one of {sorted(PLATFORMS)}")

    physical_device = record.get("physical_device")
    require(isinstance(physical_device, bool), "physical_device must be true or false")
    device_class = record.get("device_evidence_class")
    require(device_class in DEVICE_EVIDENCE_CLASSES,
            f"device_evidence_class must be one of {sorted(DEVICE_EVIDENCE_CLASSES)}")

    if backend == "native_os":
        require(platform in {"ios", "android"},
                "native_os samples must use platform ios or android")
        require(physical_device is True,
                "native_os samples require physical_device=true")
        require(device_class in {"D1", "D2", "D3"},
                "native_os samples must bind to physical device class D1, D2 or D3")
        if platform == "ios":
            require(device_class == "D1",
                    "native iOS evidence must bind to D1")
        if platform == "android":
            require(device_class in {"D2", "D3"},
                    "native Android evidence must bind to D2 or D3")
    else:
        require(device_class == "not_applicable" or physical_device is True,
                "non-native samples must use not_applicable device class unless captured on a physical device")

    locale = record.get("language_locale")
    require(isinstance(locale, str) and locale.lower().startswith("tr"),
            "language_locale must be Turkish (for example tr-TR)")

    network_requirement = record.get("voice_network_requirement")
    require(network_requirement in NETWORK_REQUIREMENTS,
            f"voice_network_requirement must be one of {sorted(NETWORK_REQUIREMENTS)}")

    offline_tested = record.get("offline_tested")
    require(isinstance(offline_tested, bool), "offline_tested must be true or false")
    offline_method = record.get("offline_test_method")
    offline_result = record.get("offline_result")
    require(offline_result in OFFLINE_RESULTS,
            f"offline_result must be one of {sorted(OFFLINE_RESULTS)}")
    if backend == "native_os":
        require(offline_tested is True, "native_os samples require a real offline test")
        require(_nonblank(offline_method),
                "native_os samples require offline_test_method")
        require(offline_result in {"pass", "fail"},
                "native_os offline_result must be pass or fail")
    elif offline_tested is False:
        require(offline_result == "not_applicable",
                "when offline_tested is false, offline_result must be not_applicable")
        require(offline_method == "not_applicable",
                "when offline_tested is false, offline_test_method must be not_applicable")

    metered = record.get("metered_external_service_invoked")
    require(isinstance(metered, bool),
            "metered_external_service_invoked must be true or false")
    if backend == "native_os":
        require(metered is False,
                "native_os benchmark samples must not invoke a metered external service")

    require(_nonblank(record.get("input_corpus_version")), "input_corpus_version must be recorded")
    corpus_item = record.get("input_corpus_item")
    require(corpus_item in CORPUS_ITEMS, "input_corpus_item must be one of A-L")
    input_hash = record.get("input_text_sha256")
    require(isinstance(input_hash, str) and bool(SHA256.fullmatch(input_hash)),
            "input_text_sha256 must be 64 lowercase hex")
    require(isinstance(record.get("input_character_count"), int) and record["input_character_count"] > 0,
            "input_character_count must be a positive integer")
    require(record.get("input_bytes") is None or
            (isinstance(record.get("input_bytes"), int) and record["input_bytes"] > 0),
            "input_bytes must be null or a positive integer")

    require(_positive(record.get("actual_duration_ms")), "actual_duration_ms must be positive")
    require(_iso_with_timezone(record.get("generation_started_at")),
            "generation_started_at must be an ISO-8601 timestamp with timezone")
    require(_positive(record.get("full_completion_latency_ms")),
            "full_completion_latency_ms must be positive")

    streaming = record.get("streaming")
    require(isinstance(streaming, bool), "streaming must be true or false")
    first_byte = record.get("first_byte_latency_ms")
    if streaming is True:
        require(_positive(first_byte), "streaming samples require positive first_byte_latency_ms")
    elif streaming is False:
        require(first_byte is None or _positive(first_byte),
                "non-streaming first_byte_latency_ms must be null or positive")

    retries = record.get("retries_count")
    require(isinstance(retries, int) and retries >= 0, "retries_count must be a non-negative integer")
    require(isinstance(record.get("errors"), list), "errors must be a list")

    cost = record.get("cost")
    require(isinstance(cost, dict), "cost must be an object")
    if isinstance(cost, dict):
        amount = cost.get("amount")
        require(cost.get("scope") == "metered_external_provider_usage",
                "cost.scope must be metered_external_provider_usage")
        require(_nonnegative(amount), "cost.amount must be non-negative")
        require(_nonblank(cost.get("unit")), "cost.unit must be recorded")
        require(_nonblank(cost.get("evidence_basis")), "cost.evidence_basis must be recorded")
        if metered is False:
            require(amount == 0,
                    "cost.amount must be 0 when no metered external service was invoked")

    checksum = record.get("audio_sha256")
    require(isinstance(checksum, str) and bool(SHA256.fullmatch(checksum)),
            "audio_sha256 must be 64 lowercase hex")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("record", help="Completed R7-07A voice sample evidence JSON")
    args = parser.parse_args()

    try:
        record = _load(args.record)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}")
        return 2

    errors = validate(record)
    if errors:
        print(f"FAIL: {len(errors)} voice-sample evidence checks failed")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(f"PASS: {record['blind_sample_id']} evidence is structurally complete")
    print("NOTE: structural completeness is not audio-quality approval, provider selection, or R7-07 PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
