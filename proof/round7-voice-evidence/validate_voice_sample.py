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

    require(record.get("schema_version") == 1, "schema_version must be 1")
    require(record.get("requirement") == "R7-07A", "requirement must be R7-07A")

    blind_id = record.get("blind_sample_id")
    require(isinstance(blind_id, str) and bool(BLIND_ID.fullmatch(blind_id)),
            "blind_sample_id must match V01, V02, ...")
    require(record.get("provider_identity_hidden_from_listener") is True,
            "provider_identity_hidden_from_listener must be true")

    for key in (
        "hidden_provider_model_voice_key",
        "provider_model_version",
        "voice_id_or_name",
        "synthesis_mode_or_quality_tier",
        "requested_format",
        "cache_reuse_behavior",
        "raw_provider_metadata_location",
        "audio_file_location",
        "known_limitation",
    ):
        require(_nonblank(record.get(key)), f"{key} must be recorded")

    locale = record.get("language_locale")
    require(isinstance(locale, str) and locale.lower().startswith("tr"),
            "language_locale must be Turkish (for example tr-TR)")

    corpus_item = record.get("input_corpus_item")
    require(corpus_item in CORPUS_ITEMS, "input_corpus_item must be one of A-L")
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
        require(_nonnegative(cost.get("amount")), "cost.amount must be non-negative")
        require(_nonblank(cost.get("unit")), "cost.unit must be recorded")

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
