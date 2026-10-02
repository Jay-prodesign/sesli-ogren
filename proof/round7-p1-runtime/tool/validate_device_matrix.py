#!/usr/bin/env python3
"""Cross-device completeness checks for the R7-06 D1/D2/D3 evidence matrix.

This complements validate_device_evidence.py. It checks matrix-level invariants
that one device record cannot prove. It does not decide device-class suitability,
numeric performance acceptability, or grant Round 7 Technical PASS.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

PASS = "PASS"
REQUIRED_CLASSES = {"D1", "D2", "D3"}


def load(path: str) -> dict[str, Any]:
    with Path(path).open("r", encoding="utf-8") as fh:
        value = json.load(fh)
    if not isinstance(value, dict):
        raise ValueError(f"{path}: top-level JSON must be an object")
    return value


def validate_matrix(records: list[dict[str, Any]]) -> list[str]:
    errors: list[str] = []

    def require(ok: bool, message: str) -> None:
        if not ok:
            errors.append(message)

    classes = [r.get("device_class") for r in records]
    require(len(records) == 3, "matrix must contain exactly three device records")
    require(set(classes) == REQUIRED_CLASSES and len(classes) == len(set(classes)),
            f"matrix must contain exactly one each of D1, D2 and D3; got {classes}")

    by_class = {r.get("device_class"): r for r in records if r.get("device_class") in REQUIRED_CLASSES}
    if len(by_class) != 3:
        return errors

    build_shas = {r.get("build_sha") for r in records}
    require(len(build_shas) == 1, "D1/D2/D3 evidence must be bound to the same build_sha")
    require(all(r.get("test_mode") == "PROFILE" for r in records),
            "all D1/D2/D3 evidence must use PROFILE mode")
    require(all(r.get("overall_result") == PASS for r in records),
            "full R7-06 matrix cannot pass unless D1, D2 and D3 are all PASS")

    models = [r.get("exact_model") for r in records]
    require(all(isinstance(m, str) and m.strip() for m in models),
            "every device class must record an exact_model")
    require(len(models) == len(set(models)),
            "D1/D2/D3 must not reuse the same exact_model record")

    d1_a11y = by_class["D1"].get("accessibility") or {}
    require(d1_a11y.get("screen_reader") == "VoiceOver" and d1_a11y.get("result") == PASS,
            "D1 must include VoiceOver PASS evidence")

    android_talkback = False
    for cls in ("D2", "D3"):
        a11y = by_class[cls].get("accessibility") or {}
        if a11y.get("screen_reader") == "TalkBack" and a11y.get("result") == PASS:
            android_talkback = True
    require(android_talkback, "at least one of D2/D3 must include TalkBack PASS evidence")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence", nargs="+", help="Three completed device evidence JSON files")
    args = parser.parse_args()

    try:
        records = [load(path) for path in args.evidence]
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}")
        return 2

    errors = validate_matrix(records)
    if errors:
        print(f"FAIL: {len(errors)} R7-06 matrix checks failed")
        for error in errors:
            print(f"  - {error}")
        return 1

    sha = records[0]["build_sha"]
    print(f"PASS: R7-06 D1/D2/D3 evidence matrix is structurally complete for build {sha}")
    print("NOTE: this does not grant R7-06 or Round 7 Technical PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
