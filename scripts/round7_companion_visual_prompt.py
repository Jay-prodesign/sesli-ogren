#!/usr/bin/env python3
"""Build design-plan-locked prompts for Round 7 Companion visual production."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SPEC_PATH = ROOT / "round7_companion_visual_spec.json"


def load_spec() -> dict:
    return json.loads(SPEC_PATH.read_text(encoding="utf-8"))


def parity_hash(spec: dict) -> str:
    raw = json.dumps(spec["parity"], ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def lint_spec(spec: dict) -> list[str]:
    errors: list[str] = []
    if set(spec.get("candidates", {})) != {"D", "E"}:
        errors.append("Exactly candidates D and E are required.")

    expected_states = [
        "AVAILABLE/IDLE",
        "LISTENING",
        "THINKING",
        "SPEAKING",
        "SUCCESS",
        "SUPPORTIVE CORRECTION",
    ]
    if spec.get("stages", {}).get("F1", {}).get("states") != expected_states:
        errors.append("F1 state contract drifted.")

    production = spec.get("production_mode", {})
    if production.get("strategy") != "design_plan_locked_generation":
        errors.append("Production strategy must be design_plan_locked_generation.")
    if production.get("design_authority") != "ROUND_7_CURRENT_FINALIST_REBUILD_BRIEF_001":
        errors.append("Canonical design authority drifted.")

    hard_fails = set(spec.get("shared_hard_fails", []))
    required = {
        "recognizable animal or pet",
        "generic blob with face",
        "generic AI orb",
        "robot assistant",
        "mini human",
        "eyes-and-mouth mascot grammar",
        "face screen or visor",
    }
    if not required.issubset(hard_fails):
        errors.append("Required anti-archetype constraints are missing.")

    for code, candidate in spec.get("candidates", {}).items():
        if not candidate.get("positive_identity"):
            errors.append(f"{code} has no identity anchors.")
        if not candidate.get("f0_geometry"):
            errors.append(f"{code} has no canonical-form instruction.")

    return errors


def shared_block(spec: dict) -> str:
    parity = "\n".join(
        f"- {key.replace('_', ' ')}: {value}" for key, value in spec["parity"].items()
    )
    fails = "; ".join(spec["shared_hard_fails"])
    return f"""LOCKED PARITY CONDITIONS
{parity}

SHARED HARD FAILS
Reject rather than reinterpret the design if the result becomes any of these:
{fails}

PRODUCTION AUTHORITY
The canonical design brief is authoritative. Tool limitations are not design input.
Do not simplify, replace, proceduralize, logo-ize, humanize, animalize, robotize, or otherwise change the candidate concept to make generation easier.
"""


def build_f0_prompt(spec: dict, candidate_code: str) -> str:
    c = spec["candidates"][candidate_code]
    identity = "\n".join(f"- {item}" for item in c["positive_identity"])
    views = "\n".join(f"- {item}" for item in spec["stages"]["F0"]["views"])
    return f"""ROUND 7 COMPANION — F0 CANONICAL CHARACTER FORM
Candidate: {c['name']}

GOAL
Create the actual Companion character direction defined below. This is not a substitute geometry exercise and not a generic mascot brief.

CANONICAL CHARACTER DIRECTION
{c['f0_geometry']}

IDENTITY ANCHORS
{identity}

REQUIRED F0 PROOF
{views}

CHARACTER REQUIREMENT
The result must feel like a living, responsive learning character rather than a logo or decorative object.
Character presence must come from the approved body grammar, attention system, orientation, asymmetry, tension and structural response.
Do not solve character presence with conventional cute eyes-and-mouth mascot grammar, human anatomy, animal anatomy, robot casing, props or costumes.

{shared_block(spec)}

Do not add marketing poster composition, lifestyle scene dressing, books, desk, classroom narrative or unrelated UI.
One candidate only. Preserve the approved candidate identity even if the generation tool would prefer a more familiar mascot form.
"""


def build_f1_prompt(spec: dict, candidate_code: str) -> str:
    c = spec["candidates"][candidate_code]
    identity = "\n".join(f"- {item}" for item in c["positive_identity"])
    states = "\n".join(f"- {state}" for state in spec["stages"]["F1"]["states"])
    return f"""ROUND 7 COMPANION — F1 SIX-STATE CHARACTER PARITY
Candidate: {c['name']}

Use the approved F0 character identity. Do not redesign the candidate.

IDENTITY ANCHORS
{identity}

REQUIRED STATES
{states}

STATE LANGUAGE
- LISTENING: attentive, not submissive/cute.
- THINKING: reflective, not loading/buffering.
- SPEAKING: readable without perfect lip-sync.
- SUCCESS: positive without loot/reward-economy grammar.
- SUPPORTIVE CORRECTION: helpful direction, never disappointment or punishment.
- AVAILABLE/IDLE: calm and present.

{shared_block(spec)}

State differences must preserve the same character identity and body grammar.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", choices=["D", "E"])
    parser.add_argument("--stage", choices=["F0", "F1"], default="F0")
    parser.add_argument("--lint", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    spec = load_spec()
    errors = lint_spec(spec)
    if args.lint:
        print(json.dumps({
            "ok": not errors,
            "errors": errors,
            "task_id": spec["task_id"],
            "design_authority": spec["production_mode"]["design_authority"],
            "parity_sha256": parity_hash(spec),
        }, ensure_ascii=False, indent=2))
        return 0 if not errors else 1

    if errors:
        raise SystemExit("Spec lint failed:\n- " + "\n- ".join(errors))
    if not args.candidate:
        raise SystemExit("--candidate is required unless --lint is used")

    prompt = build_f0_prompt(spec, args.candidate) if args.stage == "F0" else build_f1_prompt(spec, args.candidate)
    if args.json:
        print(json.dumps({
            "task_id": spec["task_id"],
            "candidate": args.candidate,
            "stage": args.stage,
            "design_authority": spec["production_mode"]["design_authority"],
            "parity_sha256": parity_hash(spec),
            "prompt": prompt,
        }, ensure_ascii=False, indent=2))
    else:
        print(prompt)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
