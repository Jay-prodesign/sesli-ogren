#!/usr/bin/env python3
"""Fail-closed completeness checks for Round 7 R7-06 physical-device evidence.

This validates one physical-device evidence record against the raw P1 report.
It does not grant R7-06 PASS: D1/D2/D3 coverage, cross-device TalkBack coverage,
Founder/Product gates, and durable Drive registration remain separate review steps.
Standard library only.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

SHA40 = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
EXPECTED_SCENARIOS = {f"T{i}" for i in range(1, 12)}
PASS = "PASS"


def load_json(path: str) -> dict[str, Any]:
    with Path(path).open("r", encoding="utf-8") as fh:
        value = json.load(fh)
    if not isinstance(value, dict):
        raise ValueError(f"{path}: top-level JSON must be an object")
    return value


def _nonblank(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip()) and value.strip().upper() not in {
        "FILL",
        "TBD",
        "TODO",
        "NOT_RUN",
        "RECORD_MANUALLY",
    }


def _positive_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value > 0


def validate(report: dict[str, Any], evidence: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    def require(condition: bool, message: str) -> None:
        if not condition:
            errors.append(message)

    require(evidence.get("schema_version") == 1, "evidence.schema_version must be 1")
    require(evidence.get("requirement") == "R7-06", "evidence.requirement must be R7-06")
    require(evidence.get("device_class") in {"D1", "D2", "D3"}, "device_class must be D1, D2 or D3")
    for key in ("evidence_id", "exact_model", "os_version", "flutter_version", "observed_at",
                "raw_timeline_location", "raw_p1_report_location", "frame_summary_observation",
                "thermal_battery_observation", "known_limitation", "reviewer"):
        require(_nonblank(evidence.get(key)), f"evidence.{key} must be recorded")

    build_sha = evidence.get("build_sha")
    checksum = evidence.get("build_checksum_sha256")
    require(isinstance(build_sha, str) and bool(SHA40.fullmatch(build_sha)), "build_sha must be 40 lowercase hex")
    require(isinstance(checksum, str) and bool(SHA256.fullmatch(checksum)), "build_checksum_sha256 must be 64 lowercase hex")
    require(evidence.get("test_mode") == "PROFILE", "test_mode must be PROFILE")
    require(_positive_number(evidence.get("refresh_rate_hz")), "refresh_rate_hz must be a positive number")

    cold = evidence.get("cold_start_ms")
    require(isinstance(cold, list) and len(cold) == 3 and all(_positive_number(x) for x in cold),
            "cold_start_ms must contain exactly 3 positive measurements")

    memory = evidence.get("memory_bytes")
    require(isinstance(memory, dict), "memory_bytes must be an object")
    if isinstance(memory, dict):
        for key in ("baseline", "world", "post_t11"):
            require(_positive_number(memory.get(key)), f"memory_bytes.{key} must be a positive number")

    for key in ("memory_unbounded_growth", "visible_repeated_jank", "thermal_blocking_issue"):
        require(isinstance(evidence.get(key), bool), f"{key} must be true or false")

    pause = evidence.get("pause_resume")
    require(isinstance(pause, dict), "pause_resume must be an object")
    if isinstance(pause, dict):
        require(pause.get("teach") == PASS, "pause_resume.teach must PASS")
        require(pause.get("challenge") == PASS, "pause_resume.challenge must PASS")

    fallbacks = evidence.get("fallbacks")
    required_fallbacks = ("reduced_motion", "audio_unavailable", "companion_asset_failure",
                          "world_asset_failure", "content_tier")
    require(isinstance(fallbacks, dict), "fallbacks must be an object")
    if isinstance(fallbacks, dict):
        for key in required_fallbacks:
            require(fallbacks.get(key) == PASS, f"fallbacks.{key} must PASS")

    accessibility = evidence.get("accessibility")
    require(isinstance(accessibility, dict), "accessibility must be an object")
    if isinstance(accessibility, dict):
        if evidence.get("device_class") == "D1":
            require(accessibility.get("screen_reader") == "VoiceOver", "D1 must record VoiceOver")
            require(accessibility.get("result") == PASS, "D1 VoiceOver accessibility result must PASS")
        if accessibility.get("result") == PASS:
            require(accessibility.get("screen_reader") in {"VoiceOver", "TalkBack"},
                    "passing accessibility evidence must name VoiceOver or TalkBack")
            for key in ("largest_text", "focus_order", "announcements"):
                require(accessibility.get(key) == PASS, f"accessibility.{key} must PASS when accessibility.result is PASS")

    overall = evidence.get("overall_result")
    require(overall in {"PASS", "CHANGE_REQUIRED", "REJECT"}, "overall_result must be PASS, CHANGE_REQUIRED or REJECT")

    require(report.get("proof") == "ROUND_7_P1_RUNTIME_PROOF_SPEC_001",
            "report.proof must be ROUND_7_P1_RUNTIME_PROOF_SPEC_001")
    require(report.get("git_sha") == build_sha, "report.git_sha must equal evidence.build_sha")
    require(report.get("build_mode") in {"profile", "release"}, "report.build_mode must be profile or release")
    expected_platform = "iOS" if evidence.get("device_class") == "D1" else "android"
    require(report.get("platform") == expected_platform,
            f"report.platform must be {expected_platform} for {evidence.get('device_class')}")
    require(report.get("decision_grade") == "ONLY_IF_PHYSICAL_DEVICE",
            "report.decision_grade must be ONLY_IF_PHYSICAL_DEVICE")

    scenarios = report.get("scenarios")
    require(isinstance(scenarios, list), "report.scenarios must be a list")
    scenario_map: dict[str, dict[str, Any]] = {}
    if isinstance(scenarios, list):
        for item in scenarios:
            if isinstance(item, dict) and isinstance(item.get("id"), str):
                scenario_map[item["id"]] = item
        require(set(scenario_map) == EXPECTED_SCENARIOS,
                f"report.scenarios must contain exactly T1-T11; got {sorted(scenario_map)}")

    if overall == PASS:
        require(report.get("functional_result") == PASS, "PASS evidence requires report.functional_result PASS")
        require(evidence.get("memory_unbounded_growth") is False, "PASS evidence cannot report unbounded memory growth")
        require(evidence.get("visible_repeated_jank") is False, "PASS evidence cannot report repeated visible jank")
        require(evidence.get("thermal_blocking_issue") is False, "PASS evidence cannot report a thermal blocking issue")
        for sid, item in scenario_map.items():
            require(item.get("result") == "FUNCTIONAL_PASS", f"{sid} must be FUNCTIONAL_PASS for overall PASS")

        t11 = scenario_map.get("T11", {})
        require(isinstance(t11.get("cycles"), int) and t11.get("cycles", 0) >= 30,
                "T11 must record at least 30 soak cycles")
        controllers = t11.get("live_controllers_before_after")
        require(isinstance(controllers, list) and len(controllers) == 2 and controllers[0] == controllers[1],
                "T11 live_controllers_before_after must show no controller leak")
        rss = t11.get("rss_samples_bytes")
        require(isinstance(rss, list) and len(rss) >= 7,
                "T11 must retain RSS samples from the 30-cycle soak")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True, help="Raw build/p1_report.json")
    parser.add_argument("--evidence", required=True, help="Completed per-device evidence JSON")
    args = parser.parse_args()

    try:
        report = load_json(args.report)
        evidence = load_json(args.evidence)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}")
        return 2

    errors = validate(report, evidence)
    if errors:
        print(f"FAIL: {len(errors)} device-evidence checks failed")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        "PASS: R7-06 device evidence is structurally complete for "
        f"{evidence['device_class']} / {evidence['exact_model']} / {evidence['build_sha']}"
    )
    print("NOTE: this is completeness validation only; it does not close R7-06.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
