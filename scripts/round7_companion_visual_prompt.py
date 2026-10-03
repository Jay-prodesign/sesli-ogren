#!/usr/bin/env python3
"""Compile locked generation and corrective prompts for Round 7 Companion production."""
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
SPEC_PATH=ROOT/"round7_companion_visual_spec.json"
def load_spec(): return json.loads(SPEC_PATH.read_text(encoding="utf-8"))
def parity_hash(s): return hashlib.sha256(json.dumps(s["parity"],ensure_ascii=False,sort_keys=True).encode()).hexdigest()
def lint_spec(s):
    e=[]
    if set(s.get("candidates",{}))!={"D","E"}: e.append("Exactly candidates D and E are required.")
    if s.get("production_mode",{}).get("strategy")!="design_plan_locked_generate_jury_repair_integrate_loop": e.append("Generate-jury-repair-integrate loop must be locked.")
    if s.get("production_mode",{}).get("design_authority")!="ROUND_7_CURRENT_FINALIST_REBUILD_BRIEF_001": e.append("Canonical design authority drifted.")
    if "motion_anatomy" not in s.get("stages",{}).get("F0",{}): e.append("F0 motion anatomy missing.")
    if "runtime_smoke" not in s.get("stages",{}).get("F0",{}): e.append("F0 runtime smoke acceptance missing.")
    if "asset_lifecycle" not in s: e.append("Asset lifecycle missing.")
    if "SOURCE_VISUAL_PASS" not in s.get("acceptance_levels",{}): e.append("Source visual acceptance missing.")
    if "PRODUCTION_ASSET_PASS" not in s.get("acceptance_levels",{}): e.append("Production asset acceptance missing.")
    if "semantic_authority_firewall" not in s: e.append("Semantic authority firewall missing.")
    for code in ("ROBOT_FACE_DRIFT","ABSTRACT_LOGO_OBJECT_DRIFT","WEAK_ATTENTION_SYSTEM","STATIC_ONLY","RUNTIME_CONTEXT_FAIL","PROHIBITED_ARCHETYPE"):
        if code not in s.get("failure_codes",{}): e.append(f"Missing failure code {code}.")
    return e
def shared(s):
    parity="\n".join(f"- {k.replace('_',' ')}: {v}" for k,v in s["parity"].items())
    fails="; ".join(s["shared_hard_fails"])
    return f"""LOCKED PARITY
{parity}

HARD FAILS — any one means REJECT
{fails}

AUTHORITY
The canonical brief is authoritative. Tool limitations are not design input. Do not redesign the character to suit the generator.
"""
def build_f0_prompt(s,candidate):
    c=s["candidates"][candidate]
    identity="\n".join(f"- {x}" for x in c["positive_identity"])
    views="\n".join(f"- {x}" for x in s["stages"]["F0"]["views"])
    anatomy="\n".join(f"- {x}" for x in s["stages"]["F0"]["motion_anatomy"])
    return f"""ROUND 7 — F0 CANONICAL FORM + MOTION ANATOMY
Candidate: {c['name']}

TARGET
Design one living, animation-ready learning character. Do not make a poster, mascot, robot, logo, sculpture or decorative knot.

FORM
{c['f0_geometry']}

IDENTITY
{identity}

FORM PROOF
{views}

MOTION ANATOMY PROOF
{anatomy}

The same body must credibly support restrained idle life, attention shift, listening, thinking and speaking without adding a face, limbs, props, particles or a second character grammar.

{shared(s)}
One candidate only. Character design sheet, not lifestyle art.

IMPORTANT ACCEPTANCE BOUNDARY
This generation can earn SOURCE VISUAL PASS only. PRODUCTION ASSET PASS requires later bounded integration through the real CompanionRenderer context and the locked runtime-context checks.
"""
def build_repair_prompt(s,candidate,failure_codes,passed_traits):
    unknown=[x for x in failure_codes if x not in s["failure_codes"]]
    if unknown: raise ValueError("Unknown failure codes: "+", ".join(unknown))
    base=build_f0_prompt(s,candidate)
    failures="\n".join(f"- {x}: {s['failure_codes'][x]}" for x in failure_codes)
    preserved="\n".join(f"- {x}" for x in passed_traits) if passed_traits else "- Preserve every aspect that already satisfies the locked contract."
    return f"""{base}
CORRECTIVE ITERATION — DO NOT START A NEW CONCEPT
Diagnosed failures:
{failures}

PRESERVE PASSED TRAITS
{preserved}

Repair only the diagnosed failure classes. Do not compensate by introducing eyes, face, robot casing, limbs, props, glow, particles, cuteness or a different character archetype. If the generator cannot make the repair while preserving the contract, reject the output rather than weakening the design.
"""
def main():
    p=argparse.ArgumentParser(); p.add_argument("--candidate",choices=["D","E"]); p.add_argument("--lint",action="store_true"); p.add_argument("--failures"); p.add_argument("--passed",default="")
    a=p.parse_args(); s=load_spec(); errors=lint_spec(s)
    if a.lint: print(json.dumps({"ok":not errors,"errors":errors,"parity_sha256":parity_hash(s)},indent=2)); return 0 if not errors else 1
    if errors: raise SystemExit("\n".join(errors))
    if not a.candidate: raise SystemExit("--candidate required")
    if a.failures:
        out=build_repair_prompt(s,a.candidate,[x.strip() for x in a.failures.split(",") if x.strip()],[x.strip() for x in a.passed.split("|") if x.strip()])
    else: out=build_f0_prompt(s,a.candidate)
    print(out); return 0
if __name__=="__main__": raise SystemExit(main())
