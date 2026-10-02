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

    production = spec.get("production_mode", {})
    if production.get("strategy") != "reference_locked_edit":
        errors.append("Production strategy must be reference_locked_edit.")
    seed = spec.get("seed_control", {})
    if seed.get("variants_per_candidate") != 3:
        errors.append("Exactly three geometry seed variants per candidate are required.")

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
    production = spec["production_mode"]
    return f"""ROUND 7 COMPANION — F0 REFERENCE-LOCKED MATERIALIZATION
Candidate: {c['name']}

INPUT AUTHORITY
Use the ATTACHED geometry control seed as the sole positive visual reference. Previous mascot/poster renders are rejected history and must not influence the image.

TASK
Materialize the attached geometry seed into a production-quality non-human learning Companion while PRESERVING its outer silhouette, negative-space topology, part count, and candidate-specific structural identity.

TOPOLOGY LOCK
{production['topology_lock']}

PRIMARY GEOMETRY
{c['f0_geometry']}

IDENTITY ANCHORS
{identity}

EDIT BOUNDARY
- keep the same candidate only;
- do not invent a head, face, eyes, mouth, limbs, hands, feet, ears, tail, hair, clothing, props, UI symbols, badges, speech bubbles, environment, books, desk, phone, classroom, stars or decorative scene;
- do not add glow, particles, aura, neon rim light or cinematic background;
- do not convert structural apertures into eyes;
- do not add text;
- use restrained matte soft-touch material and neutral studio shading only;
- improve thickness, edge quality, spatial depth and material finish without changing topology.

{_shared_block(spec)}

QUALITY BAR
- the silhouette must remain recognizable before color;
- the form must feel responsive/alive through structural tension and orientation, not facial acting;
- mature enough for teen, adult and professional learning contexts;
- low-part-count and plausible for vector/CustomPaint/Rive translation;
- output ONE isolated candidate on the neutral studio field, centered with generous margins.

This is a controlled materialization/edit of the supplied seed, not a new character design and not a poster.
"""

def build_f1_prompt(spec: dict, candidate_code: str) -> str:
    c = spec["candidates"][candidate_code]
    states = "\n".join(f"- {s}" for s in spec["stages"]["F1"]["states"])
    identity = "\n".join(f"- {x}" for x in c["positive_identity"])
    return f"""ROUND 7 COMPANION — F1 REFERENCE-LOCKED STATE EDIT
Candidate: {c['name']}

INPUT AUTHORITY
Use the ATTACHED approved F0 canonical form as the sole positive visual reference. Do not redesign the character and do not borrow anatomy or styling from previous rejected mascot renders.

IDENTITY ANCHORS
{identity}

REQUIRED STATES
{states}

STATE LANGUAGE
- LISTENING: attentive through orientation/tension only; not cute or submissive.
- THINKING: reflective structural tension; never loading/buffering iconography.
- SPEAKING: subtle form rhythm; no mouth and no lip-sync dependency.
- SUCCESS: composed positive expansion; no reward/loot/confetti grammar.
- SUPPORTIVE CORRECTION: directional help and guidance; never disappointment, shame or punishment.
- AVAILABLE/IDLE: calm, present and low-attention.

{_shared_block(spec)}

STATE-EDIT LOCK
Keep the approved F0 silhouette family, negative-space topology, material, camera, scale and lighting. State changes may use only bounded whole-form deformation, orientation, compression/expansion, spacing and internal structural alignment. Never add props, particles, facial features, floating UI symbols or new body parts.
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
