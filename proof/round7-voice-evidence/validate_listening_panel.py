#!/usr/bin/env python3
"""Fail-closed completeness checks for an R7-07A blind Turkish listening panel.

This validator never ranks candidates or selects a provider. It checks only that
the blind panel record is complete enough for human review.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

BLIND_ID = re.compile(r"^V[0-9]{2,}$")
DIMENSIONS = {
    "native_turkish_naturalness",
    "pronunciation_accuracy",
    "prosody",
    "sentence_rhythm",
    "question_intonation",
    "warmth",
    "teacher_credibility",
    "non_robotic_quality",
    "academic_clarity",
    "long_form_consistency",
    "emotion_control",
    "chunk_boundary_continuity",
    "rapid_turn_consistency",
    "companion_personality_fit",
}


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


def validate(panel: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    def require(ok: bool, message: str) -> None:
        if not ok:
            errors.append(message)

    require(panel.get("schema_version") == 1, "schema_version must be 1")
    require(panel.get("requirement") == "R7-07A", "requirement must be R7-07A")
    require(_nonblank(panel.get("panel_id")), "panel_id must be recorded")
    require(panel.get("provider_identity_exposed_to_listeners") is False,
            "provider_identity_exposed_to_listeners must be false")
    require(isinstance(panel.get("playback_order_randomized"), bool),
            "playback_order_randomized must be true or false")

    sample_ids = panel.get("blind_sample_ids")
    require(isinstance(sample_ids, list) and bool(sample_ids), "blind_sample_ids must be a non-empty list")
    if isinstance(sample_ids, list):
        require(all(isinstance(x, str) and BLIND_ID.fullmatch(x) for x in sample_ids),
                "every blind_sample_id must match V01, V02, ...")
        require(len(sample_ids) == len(set(sample_ids)), "blind_sample_ids must be unique")
    expected = set(sample_ids) if isinstance(sample_ids, list) else set()

    participants = panel.get("participants")
    require(isinstance(participants, list) and bool(participants), "participants must be a non-empty list")
    codes: list[str] = []
    if isinstance(participants, list):
        for i, person in enumerate(participants):
            prefix = f"participants[{i}]"
            if not isinstance(person, dict):
                errors.append(f"{prefix} must be an object")
                continue
            code = person.get("participant_code")
            require(_nonblank(code), f"{prefix}.participant_code must be recorded")
            if isinstance(code, str):
                codes.append(code)
            require(person.get("consent_recorded") is True, f"{prefix}.consent_recorded must be true")
            require(person.get("turkish_fluency") in {"native", "near_native"},
                    f"{prefix}.turkish_fluency must be native or near_native")
            require(_nonblank(person.get("listening_device")), f"{prefix}.listening_device must be recorded")
            order = person.get("sample_order")
            require(isinstance(order, list) and set(order) == expected and len(order) == len(expected),
                    f"{prefix}.sample_order must contain each blind sample exactly once")

            ratings = person.get("ratings")
            require(isinstance(ratings, dict), f"{prefix}.ratings must be an object")
            if isinstance(ratings, dict):
                require(set(ratings) == expected,
                        f"{prefix}.ratings must cover exactly the blind_sample_ids")
                for sid, dims in ratings.items():
                    if not isinstance(dims, dict):
                        errors.append(f"{prefix}.ratings[{sid}] must be an object")
                        continue
                    require(set(dims) == DIMENSIONS,
                            f"{prefix}.ratings[{sid}] must contain all canonical dimensions exactly once")
                    for dim, score in dims.items():
                        require(isinstance(score, int) and 1 <= score <= 5,
                                f"{prefix}.ratings[{sid}].{dim} must be an integer 1-5")

            defects = person.get("critical_defects")
            require(isinstance(defects, dict), f"{prefix}.critical_defects must be an object")
            if isinstance(defects, dict):
                require(set(defects) == expected,
                        f"{prefix}.critical_defects must cover exactly the blind_sample_ids")
                for sid, values in defects.items():
                    require(isinstance(values, list), f"{prefix}.critical_defects[{sid}] must be a list")

    require(len(codes) == len(set(codes)), "participant_code values must be unique")
    require(panel.get("automated_winner_or_ranking") is False,
            "automated_winner_or_ranking must be false")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("panel", help="Completed blind listening panel JSON")
    args = parser.parse_args()

    try:
        panel = _load(args.panel)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}")
        return 2

    errors = validate(panel)
    if errors:
        print(f"FAIL: {len(errors)} listening-panel checks failed")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("PASS: blind listening panel is structurally complete for human review")
    print("NOTE: no candidate ranking, provider selection, or R7-07 PASS is produced.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
