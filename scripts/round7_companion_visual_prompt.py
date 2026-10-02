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
    if s.get("production_mode",{}).get("strategy")!="design_plan_locked_generate_jury_repair_loop": e.append("Generate-jury-repair loop must be locked.")
    if s.get("production_mode",{}).get("design_authority")!="ROUND_7_CURRENT_FINALIST_REBUILD_BRIEF_001": e.append("Canonical design authority drifted.")
    if "motion_anatomy" not in s.get("stages",{}).get("F0",{}): e.append("F0 motion anatomy missing.")
    for code in ("ROBOT_FACE_DRIFT","ABSTRACT_LOGO_OBJECT_DRIFT","WEAK_ATTENTION_SYSTEM","STATIC_ONLY","PROHIBITED_ARCHETYPE"):
        if code not in s.get("failure_codes",{}): e.append(f"Missing failure code {code}.")
    return e
def shared(s):
    parity="\n".join(f"- {k.replace('_',' ')}: {v}" for k,v in s["parity"].items())
    fails="; ".join(s["shared_hard_fails"])
    return f"""LOCKED PARITY\n{parity}\n\nHARD FAILS — any one means REJECT\n{fails}\n\nAUTHORITY\nThe canonical brief is authoritative. Tool limitations are not design input. Do not redesign the character to suit the generator.\n"""
def build_f0_prompt(s,candidate):
    c=s["candidates"][candidate]
    identity="\n".join(f"- {x}" for x in c["positive_identity"])
    views="\n".join(f"- {x}" for x in s["stages"]["F0"]["views"])
    anatomy="\n".join(f"- {x}" for x in s["stages"]["F0"]["motion_anatomy"])
    return f"""ROUND 7 — F0 CANONICAL FORM + MOTION ANATOMY\nCandidate: {c['name']}\n\nTARGET\nDesign one living, animation-ready learning character. Do not make a poster, mascot, robot, logo, sculpture or decorative knot.\n\nFORM\n{c['f0_geometry']}\n\nIDENTITY\n{identity}\n\nFORM PROOF\n{views}\n\nMOTION ANATOMY PROOF\n{anatomy}\n\nThe same body must credibly support restrained idle life, attention shift, listening, thinking and speaking without adding a face, limbs, props, particles or a second character grammar.\n\n{shared(s)}\nOne candidate only. Character design sheet, not lifestyle art.\n"""
def build_repair_prompt(s,candidate,failure_codes,passed_traits):
    unknown=[x for x in failure_codes if x not in s["failure_codes"]]
    if unknown: raise ValueError("Unknown failure codes: "+", ".join(unknown))
    base=build_f0_prompt(s,candidate)
    failures="\n".join(f"- {x}: {s['failure_codes'][x]}" for x in failure_codes)
    preserved="\n".join(f"- {x}" for x in passed_traits) if passed_traits else "- Preserve every aspect that already satisfies the locked contract."
    return f"""{base}\nCORRECTIVE ITERATION — DO NOT START A NEW CONCEPT\nDiagnosed failures:\n{failures}\n\nPRESERVE PASSED TRAITS\n{preserved}\n\nRepair only the diagnosed failure classes. Do not compensate by introducing eyes, face, robot casing, limbs, props, glow, particles, cuteness or a different character archetype. If the generator cannot make the repair while preserving the contract, reject the output rather than weakening the design.\n"""
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
