#!/usr/bin/env python3
"""Repository control validation for Sesli Öğren (Learning App).

Standard library only. Checks the engineering control plane, not application
code (none exists at bootstrap). Run from anywhere:

    python3 scripts/validate_bootstrap.py

Exit code 0 = all checks passed, 1 = one or more failures.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

REQUIRED_FILES = [
    "README.md",
    "CLAUDE.md",
    "AGENTS.md",
    "TASKS.md",
    ".gitignore",
    ".editorconfig",
    "docs/agent/README.md",
    "docs/agent/CURRENT_HANDOFF.md",
    "docs/agent/ENGINEER_RETURN.md",
    "docs/agent/DECISION_REQUEST.md",
    "docs/agent/EXECUTION_STATE.json",
    "docs/exec-plans/README.md",
    "docs/architecture/README.md",
    "docs/adr/README.md",
    "docs/provenance/README.md",
    "docs/qa/README.md",
    "scripts/README.md",
]

REQUIRED_DIRS = [
    "docs/agent",
    "docs/exec-plans",
    "docs/architecture",
    "docs/adr",
    "docs/provenance",
    "docs/qa",
    "scripts",
    ".github/workflows",
]

# File names that must never be committed.
FORBIDDEN_NAME_PATTERNS = [
    r"(^|/)\.env(\..+)?$",
    r"\.(pem|key|p12|pfx|jks|keystore)$",
    r"(^|/)id_(rsa|dsa|ecdsa|ed25519)(\.pub)?$",
    r"(^|/)(credentials|client_secret|service-account)[^/]*\.json$",
    r"(^|/)\.netrc$",
]
FORBIDDEN_NAME_ALLOW = {".env.example"}

# Obvious secret material. Patterns are written so they do not match themselves.
SECRET_PATTERNS = {
    "GitHub token": r"gh[pousr]_[A-Za-z0-9]{36,}",
    "GitHub fine-grained PAT": r"github_pat_[A-Za-z0-9_]{22,}",
    "Anthropic API key": r"sk-ant-[A-Za-z0-9_\-]{20,}",
    "OpenAI-style API key": r"sk-[A-Za-z0-9]{32,}",
    "AWS access key ID": r"AKIA[0-9A-Z]{16}",
    "Google API key": r"AIza[0-9A-Za-z_\-]{35}",
    "Google OAuth token": r"ya29\.[0-9A-Za-z_\-]{20,}",
    "Slack token": r"xox[abprs]-[A-Za-z0-9\-]{10,}",
    "Private key block": r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    "Service-account private_key field": r"\"private_key\"\s*:\s*\"-",
}

# Local machine paths that would leak personal information.
PERSONAL_PATH_PATTERNS = {
    "Windows user path": r"[A-Za-z]:[\\/]+Users[\\/]+[^\\/\s]+",
    "Unix home path": r"/(?:Users|home)/[A-Za-z0-9._\-]+/",
}

TEXT_SUFFIXES = {".md", ".json", ".yml", ".yaml", ".py", ".sh", ".txt", ".toml"}
TEXT_NAMES = {".gitignore", ".gitattributes", ".editorconfig"}

TASK_STATUSES = {
    "PLANNED",
    "NOT_EXECUTABLE",
    "READY",
    "IN_PROGRESS",
    "BLOCKED",
    "CHANGES_REQUIRED",
    "AWAITING_BRAIN_REVIEW",
    "DONE",
    "CANCELLED",
}
FUTURE_TASK_STATUSES = {"PLANNED", "NOT_EXECUTABLE", "CANCELLED"}
MILESTONE_STATUSES = {"ACTIVE", "PLANNED / NOT_EXECUTABLE", "DONE"}
TASK_FIELDS = ["Status", "Depends on", "Owner", "Executor", "Verification", "Exec plan"]
STATE_STATUSES = {
    "IN_PROGRESS",
    "BLOCKED",
    "AWAITING_BRAIN_REVIEW",
    "CHANGES_REQUIRED",
    "PASS",
    "IDLE",
}

AGENTS_TOPICS = [
    "Roles",
    "Authority hierarchy",
    "Sources of truth",
    "Project isolation",
    "Investigate before modify",
    "Git, PR, and test discipline",
    "Security and provenance",
    "Protected actions",
    "Handoff / return protocol",
    "Task map rules",
    "Verdict evidence",
]

CLAUDE_READ_ORDER = [
    "AGENTS.md",
    "docs/agent/CURRENT_HANDOFF.md",
    "TASKS.md",
    "docs/exec-plans/",
    "docs/agent/EXECUTION_STATE.json",
]


class Report:
    def __init__(self) -> None:
        self.failures: list[str] = []
        self.checks = 0

    def check(self, ok: bool, message: str) -> bool:
        self.checks += 1
        if not ok:
            self.failures.append(message)
        return ok


def repo_files() -> list[str]:
    """Tracked plus untracked-but-not-ignored files, relative POSIX paths."""
    try:
        out = subprocess.run(
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            cwd=ROOT,
            check=True,
            capture_output=True,
        ).stdout.decode("utf-8")
        files = sorted({f for f in out.split("\0") if f})
    except (OSError, subprocess.CalledProcessError):
        files = sorted(
            p.relative_to(ROOT).as_posix()
            for p in ROOT.rglob("*")
            if p.is_file() and ".git" not in p.relative_to(ROOT).parts
        )
    return [f for f in files if (ROOT / f).is_file()]


def read_text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def check_required(r: Report) -> None:
    for rel in REQUIRED_FILES:
        r.check((ROOT / rel).is_file(), f"required file missing: {rel}")
    for rel in REQUIRED_DIRS:
        path = ROOT / rel
        r.check(path.is_dir(), f"required directory missing: {rel}")
    workflows = list((ROOT / ".github/workflows").glob("*.y*ml"))
    r.check(bool(workflows), "no workflow file in .github/workflows")


def is_text_candidate(rel: str) -> bool:
    p = Path(rel)
    return p.suffix.lower() in TEXT_SUFFIXES or p.name in TEXT_NAMES


def check_files(r: Report, files: list[str]) -> None:
    for rel in files:
        name = Path(rel).name
        if name not in FORBIDDEN_NAME_ALLOW:
            for pat in FORBIDDEN_NAME_PATTERNS:
                r.check(
                    not re.search(pat, rel, re.IGNORECASE),
                    f"forbidden secret-bearing file present: {rel}",
                )

        data = (ROOT / rel).read_bytes()
        if is_text_candidate(rel):
            r.check(b"\0" not in data, f"control text contains NUL bytes: {rel}")
            try:
                text = data.decode("utf-8")
            except UnicodeDecodeError as exc:
                r.check(False, f"not valid UTF-8: {rel} ({exc})")
                continue
            r.check(bool(text.strip()), f"text file is empty: {rel}")
        else:
            text = data.decode("utf-8", errors="replace")

        for label, pat in SECRET_PATTERNS.items():
            m = re.search(pat, text)
            r.check(m is None, f"possible {label} in {rel}")
        for label, pat in PERSONAL_PATH_PATTERNS.items():
            m = re.search(pat, text)
            r.check(m is None, f"{label} found in {rel}: {m.group(0) if m else ''}")


def load_state(r: Report) -> dict | None:
    rel = "docs/agent/EXECUTION_STATE.json"
    if not (ROOT / rel).is_file():
        return None
    try:
        state = json.loads(read_text(rel))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        r.check(False, f"{rel} does not parse: {exc}")
        return None
    r.check(isinstance(state, dict), f"{rel} must be a JSON object")
    return state if isinstance(state, dict) else None


def check_state(r: Report, state: dict, task_status: dict[str, str]) -> None:
    rel = "docs/agent/EXECUTION_STATE.json"
    for key in ["schema_version", "project", "repository", "mission", "status", "git", "next_handoff"]:
        r.check(key in state, f"{rel}: missing key '{key}'")

    repo = state.get("repository", {}) or {}
    for key in ["url", "owner", "name", "visibility", "default_branch"]:
        r.check(bool(repo.get(key)), f"{rel}: repository.{key} missing")
    r.check(repo.get("visibility") == "PUBLIC", f"{rel}: repository.visibility must be PUBLIC (D-023)")

    r.check(bool((state.get("mission") or {}).get("id")), f"{rel}: mission.id missing")
    status = state.get("status")
    r.check(status in STATE_STATUSES, f"{rel}: status '{status}' not in {sorted(STATE_STATUSES)}")

    git = state.get("git", {}) or {}
    for key in ["branch", "base_sha", "head_sha", "pr_number", "pr_url", "merged"]:
        r.check(key in git, f"{rel}: git.{key} missing")
    sha_re = re.compile(r"^[0-9a-f]{40}$")
    r.check(bool(sha_re.match(str(git.get("base_sha", "")))), f"{rel}: git.base_sha must be a 40-hex SHA")
    if git.get("head_sha") is not None:
        r.check(bool(sha_re.match(str(git["head_sha"]))), f"{rel}: git.head_sha must be a 40-hex SHA")
    if status == "AWAITING_BRAIN_REVIEW":
        for key in ["head_sha", "pr_number", "pr_url"]:
            r.check(git.get(key) not in (None, ""), f"{rel}: git.{key} required when AWAITING_BRAIN_REVIEW")
    r.check(git.get("merged") is False, f"{rel}: git.merged must be false (agents do not merge)")

    nxt = state.get("next_handoff", {}) or {}
    r.check(bool(nxt.get("id")) and bool(nxt.get("status")), f"{rel}: next_handoff.id/status missing")

    for task_id, s in (state.get("tasks") or {}).items():
        r.check(task_id in task_status, f"{rel}: task {task_id} not found in TASKS.md")
        if task_id in task_status:
            r.check(
                task_status[task_id] == s,
                f"{rel}: task {task_id} status '{s}' != TASKS.md '{task_status[task_id]}'",
            )


def check_contracts(r: Report, state: dict | None) -> None:
    if (ROOT / "CLAUDE.md").is_file():
        claude = read_text("CLAUDE.md")
        r.check("@AGENTS.md" in claude, "CLAUDE.md must import @AGENTS.md")
        r.check("Primary Engineer" in claude, "CLAUDE.md must establish the Primary Engineer role")
        positions = [claude.find(p, claude.find("read order")) for p in CLAUDE_READ_ORDER]
        r.check(all(p >= 0 for p in positions), "CLAUDE.md read order is missing a required path")
        r.check(positions == sorted(positions), "CLAUDE.md read order is out of sequence")

    if (ROOT / "AGENTS.md").is_file():
        headings = [
            line.lower() for line in read_text("AGENTS.md").splitlines() if line.startswith("#")
        ]
        for topic in AGENTS_TOPICS:
            r.check(
                any(topic.lower() in h for h in headings),
                f"AGENTS.md missing section: {topic}",
            )

    if state and (ROOT / "docs/agent/CURRENT_HANDOFF.md").is_file():
        handoff = read_text("docs/agent/CURRENT_HANDOFF.md")
        mission_id = (state.get("mission") or {}).get("id", "")
        r.check(mission_id in handoff, f"CURRENT_HANDOFF.md does not name active mission {mission_id}")
        nxt = state.get("next_handoff") or {}
        if nxt.get("status") == "NOT_EXECUTABLE":
            r.check(
                nxt.get("id", "") in handoff and "NOT_EXECUTABLE" in handoff,
                f"CURRENT_HANDOFF.md must mark {nxt.get('id')} as NOT_EXECUTABLE",
            )


def check_tasks(r: Report) -> dict[str, str]:
    """Validate TASKS.md; return {task_id: status}."""
    rel = "TASKS.md"
    if not (ROOT / rel).is_file():
        return {}
    lines = read_text(rel).splitlines()

    heading_re = re.compile(r"^(#{2,5}) (.+?)\s*$")
    kinds = {2: r"Milestone M\d+\+? — .+", 3: r"Sprint M\d+\.S\d+ — .+", 4: r"Section M\d+\.S\d+\.[A-Z] — .+", 5: r"LA-\d{4} — .+"}
    field_re = re.compile(r"^- ([A-Za-z ]+): (.+)$")

    nodes: list[dict] = []
    current: dict | None = None
    parents: dict[int, dict | None] = {2: None, 3: None, 4: None}
    for lineno, line in enumerate(lines, 1):
        m = heading_re.match(line)
        if m:
            level, title = len(m.group(1)), m.group(2)
            r.check(
                bool(re.fullmatch(kinds[level], title)),
                f"TASKS.md:{lineno}: level-{level} heading '{title}' does not match expected form",
            )
            if level > 2:
                r.check(
                    parents.get(level - 1) is not None,
                    f"TASKS.md:{lineno}: '{title}' has no parent at level {level - 1} (hierarchy break)",
                )
            current = {"level": level, "title": title, "line": lineno, "fields": {}, "milestone": None}
            for deeper in range(level, 5):
                parents[deeper] = None
            if level < 5:
                parents[level] = current
            current["milestone"] = current if level == 2 else parents[2]
            nodes.append(current)
            continue
        f = field_re.match(line)
        if f and current is not None:
            current["fields"][f.group(1)] = f.group(2).strip()

    milestones = [n for n in nodes if n["level"] == 2]
    tasks = [n for n in nodes if n["level"] == 5]
    r.check(bool(milestones), "TASKS.md: no milestones")
    r.check(bool(tasks), "TASKS.md: no tasks")

    for ms in milestones:
        s = ms["fields"].get("Status")
        r.check(s in MILESTONE_STATUSES, f"TASKS.md:{ms['line']}: milestone status '{s}' invalid")

    ids: dict[str, str] = {}
    for t in tasks:
        tid = t["title"].split(" ")[0]
        r.check(tid not in ids, f"TASKS.md:{t['line']}: duplicate task ID {tid}")
        fields = t["fields"]
        status = fields.get("Status", "")
        ids[tid] = status
        for name in TASK_FIELDS:
            r.check(bool(fields.get(name)), f"TASKS.md: {tid} missing field '{name}'")
        r.check(status in TASK_STATUSES, f"TASKS.md: {tid} status '{status}' invalid")

        ms = t["milestone"] or {"fields": {}}
        ms_status = ms["fields"].get("Status")
        if ms_status != "ACTIVE":
            r.check(
                status in FUTURE_TASK_STATUSES or ms_status == "DONE",
                f"TASKS.md: {tid} is executable under non-active milestone",
            )
            continue

        plan = fields.get("Exec plan", "")
        pm = re.search(r"\(([^)]+)\)", plan) or re.search(r"`([^`]+)`", plan)
        target = pm.group(1) if pm else plan
        r.check(
            target == f"docs/exec-plans/{tid}.md",
            f"TASKS.md: {tid} exec plan pointer '{target}' should be docs/exec-plans/{tid}.md",
        )
        plan_path = ROOT / target
        if r.check(plan_path.is_file(), f"TASKS.md: {tid} exec plan does not resolve: {target}"):
            plan_text = plan_path.read_text(encoding="utf-8")
            r.check(tid in plan_text.splitlines()[0], f"{target}: title line must name {tid}")
            sm = re.search(r"\*\*Status:\*\*\s*([A-Z_]+)", plan_text)
            if sm:
                r.check(sm.group(1) == status, f"{target}: status '{sm.group(1)}' != TASKS.md '{status}'")

    for t in tasks:
        tid = t["title"].split(" ")[0]
        deps = t["fields"].get("Depends on", "")
        if deps.lower() != "none":
            for dep in re.findall(r"LA-\d{4}", deps):
                r.check(dep in ids, f"TASKS.md: {tid} depends on unknown task {dep}")

    nm = re.search(r"Next unallocated ID: \*\*(LA-\d{4})\*\*", "\n".join(lines))
    if r.check(nm is not None, "TASKS.md: 'Next unallocated ID' line missing") and ids:
        r.check(
            nm.group(1) > max(ids),
            f"TASKS.md: next unallocated ID {nm.group(1)} must exceed highest used {max(ids)}",
        )
    return ids


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    r = Report()
    check_required(r)
    files = repo_files()
    check_files(r, files)
    task_status = check_tasks(r)
    state = load_state(r)
    if state is not None:
        check_state(r, state, task_status)
    check_contracts(r, state)

    if r.failures:
        print(f"FAIL: {len(r.failures)} of {r.checks} checks failed")
        for msg in r.failures:
            print(f"  - {msg}")
        return 1
    print(f"OK: {r.checks} checks passed across {len(files)} files, {len(task_status)} tasks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
