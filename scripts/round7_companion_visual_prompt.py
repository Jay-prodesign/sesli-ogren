#!/usr/bin/env python3
"""Build parity-locked prompts for Round 7 Companion visual production."""

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
    candidates = spec.get("candidates", {})
    if set(candidates) != {"D", "E"}:
        errors.append("Exactly candidates D and E are required.")
    states = spec.get("stages", {}).get("F1", {}).get("states", [])
    expected = [
        "AVAILABLE/IDLE",
        "LISTENING",
        "THINKING",
        "SPEAKING",
        "SUCCESS",
        "SUPPORTIVE CORRECTION",
    ]
    if states != expected:
        errors.append("F1 state list or ordering drifted from the locked six-state contract.")

    parity = spec.get("parity", {})
    required_parity = {
        "canvas",
        "camera",
        "background",
        "lighting",
        "material",
        "screen_footprint",
        "detail_budget",
        "effects",
        "props",
        "text_policy",
        "emotion_policy",
        "runtime_translation",
    }
    missing = sorted(required_parity - set(parity))
    if missing:
        errors.append(f"Missing parity fields: {', '.join(missing)}")

    hard_fails = set(spec.get("shared_hard_fails", []))
    required_fails = {
        "recognizable animal or pet",
        "generic blob with face",
        "generic AI orb",
        "robot assistant",
        "mini human",
        "eyes-and-mouth mascot grammar",
        "arms, hands, legs, feet, ears, tail, hair, clothing, hat, glasses or props",
        "face screen or visor",
    }
    if not required_fails.issubset(hard_fails):
        errors.append("Shared hard-fail list lost required anti-mascot constraints.")

    for code, candidate in candidates.items():
        if not candidate.get("positive_identity"):
            errors.append(f"{code} has no positive identity anchors.")
        if not candidate.get("f0_geometry"):
            errors.append(f"{code} has no F0 geometry instruction.")

    return errors


def _shared_block(spec: dict) -> str:
    parity = spec["parity"]
    hard_fails = "; ".join(spec["shared_hard_fails"])
    parity_lines = "\n".join(f"- {k.replace('_', ' ')}: {v}" for k, v in parity.items())
    return f"""LOCKED PARITY CONDITIONS
{parity_lines}

ABSOLUTE HARD FAILS
Do not generate any of the following: {hard_fails}.
If a familiar mascot shorthand would help readability, do NOT use it. Preserve the abstract-living structural identity instead.
"""


def build_f0_prompt(spec: dict, candidate_code: str) -> str:
    c = spec["candidates"][candidate_code]
    identity = "\n".join(f"- {x}" for x in c["positive_identity"])
    views = "\n".join(f"- {x}" for x in spec["stages"]["F0"]["views"])
    return f"""ROUND 7 COMPANION — F0 CANONICAL FORM PROOF
Candidate: {c['name']}

TASK
Design a production-quality non-human learning Companion character. This is character-form development, not a marketing poster, lifestyle scene, game mascot, toy render, or generic AI assistant.

PRIMARY GEOMETRY
{c['f0_geometry']}

IDENTITY ANCHORS
{identity}

REQUIRED F0 OUTPUTS IN ONE CLEAN DESIGN SHEET
{views}

{_shared_block(spec)}

QUALITY BAR
- silhouette must be distinctive before color or lighting;
- form must feel alive/responsive without eyes, mouth, limbs, face, costume or props;
- mature enough for teen, adult and professional learning contexts;
- quiet enough to sit beside dense educational content for long sessions;
- low-part-count geometry with believable translation to vector/CustomPaint/Rive;
- no decorative environment; no books, desks, phones, classrooms, stars, particles or scene storytelling;
- no glow dependency;
- no candidate-vs-candidate comparison inside this image;
- do not add extra characters.

Render as a restrained industrial/character-design sheet with neutral studio material and clean spacing. The character itself is the subject.
"""


def build_f1_prompt(spec: dict, candidate_code: str) -> str:
    c = spec["candidates"][candidate_code]
    states = "\n".join(f"- {s}" for s in spec["stages"]["F1"]["states"])
    identity = "\n".join(f"- {x}" for x in c["positive_identity"])
    return f"""ROUND 7 COMPANION — F1 SIX-STATE PARITY
Candidate: {c['name']}

Use the SAME approved canonical geometry for this candidate. Do not redesign the character.

IDENTITY ANCHORS
{identity}

REQUIRED STATES
{states}

STATE LANGUAGE
- LISTENING: attentive, not cute or submissive.
- THINKING: reflective structural tension; never loading/buffering iconography.
- SPEAKING: subtle form rhythm; no mouth and no lip-sync dependency.
- SUCCESS: composed positive expansion; no reward/loot/confetti grammar.
- SUPPORTIVE CORRECTION: directional help and guidance; never disappointment, shame or punishment.
- AVAILABLE/IDLE: calm, present and low-attention.

{_shared_block(spec)}

Keep framing, scale, material, camera and lighting identical across all six cells. State changes must come from bounded whole-form deformation/orientation/internal structural alignment, not added props, effects, facial features or floating UI symbols.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", choices=["D", "E"])
    parser.add_argument("--stage", choices=["F0", "F1"], default="F0")
    parser.add_argument("--lint", action="store_true")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable output.")
    args = parser.parse_args()

    spec = load_spec()
    errors = lint_spec(spec)
    if args.lint:
        payload = {
            "ok": not errors,
            "errors": errors,
            "task_id": spec["task_id"],
            "parity_sha256": parity_hash(spec),
        }
        print(json.dumps(payload, ensure_ascii=False, indent=2))
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
            "parity_sha256": parity_hash(spec),
            "prompt": prompt,
        }, ensure_ascii=False, indent=2))
    else:
        print(prompt)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
