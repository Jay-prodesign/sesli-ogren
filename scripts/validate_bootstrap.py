#!/usr/bin/env python3
"""Repository control validation for Sesli Öğren (Learning App).

Standard library only. Checks the engineering control plane, not application
code (none exists at bootstrap): required surfaces, secrets/paths, TASKS.md
hierarchy + whole-V0 skeleton, exec-plan contracts, EXECUTION_STATE.json, D-024
reuse register/rules, D-026 command/return bus + pointers + executability guard,
.claude/ scope and workflow safety. Run from anywhere:

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
    "docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md",
    "docs/qa/README.md",
    "docs/agent/commands/README.md",
    "docs/agent/returns/README.md",
    ".claude/rules/README.md",
    "scripts/README.md",
    "scripts/test_validate_bootstrap.py",
    ".github/workflows/bootstrap-validation.yml",
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
    "docs/agent/commands",
    "docs/agent/returns",
    ".claude/rules",
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
    "Open-source reuse",
    "command / return bus",
    "Engineering quality",
]

CLAUDE_READ_ORDER = [
    "AGENTS.md",
    "CLAUDE.md",
    ".claude/rules/",
    "docs/agent/CURRENT_HANDOFF.md",
    "TASKS.md",
    "docs/exec-plans/",
    "docs/agent/EXECUTION_STATE.json",
    "docs/agent/commands/",
    "docs/agent/ENGINEER_RETURN.md",
]

# D-024 reuse control.
REUSE_CLASSES = ["DIRECT-REUSE", "ADAPT", "DEPENDENCY", "PATTERN-ONLY", "BLOCKED"]
REUSE_AUDIT_STATUSES = {"CANDIDATE", "AUDIT_IN_PROGRESS", "APPROVED", "REJECTED", "WITHDRAWN", "SUPERSEDED"}
REGISTER = "docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md"
REGISTER_FIELDS = [
    "Task ID",
    "Upstream repository",
    "Exact tag / commit / version",
    "License",
    "Reuse class",
    "Dependency / files / modules used",
    "Material modifications",
    "Copyright / license / NOTICE obligations",
    "Audit status",
    "Approving decision / task",
]
AGENTS_QUALITY_PHRASES = ["D-029", "Final Engineering Test", "D-028", "Quality considerations (D-029)"]
PLAN_QUALITY_SECTION = "Quality considerations (D-029)"

AGENTS_REUSE_PHRASES = [
    "must not be rewritten merely to make it internally authored",
    "Unapproved dependencies remain prohibited",
    "concrete reason",
    "provenance/register update",
    "OPEN_SOURCE_REUSE_REGISTER.md",
]

# Execution-plan contract (D-019 / M3 checklist E3).
PLAN_SECTIONS = [
    "Objective",
    "Authoritative source references",
    "In scope",
    "Out of scope",
    "Dependencies",
    "Acceptance criteria",
    "Required tests / evidence",
    "Rollback / migration notes",
    "Escalation conditions",
    "Expected return",
]

# Whole-V0 skeleton (D-020 master sequence) that TASKS.md must expose.
V0_SKELETON = [
    "Architecture Proof",
    "VS-001",
    "V0 Implementation Tranches",
    "Beta / Validation",
    "Brand/Name Freeze & Release Readiness",
    "Controlled Public V0 Release",
    "Post-Launch Learning / V1 Admission",
]
REQUIRED_TASKS = ["LA-0001", "LA-0002", "LA-0003", "LA-0004", "LA-0005", "LA-0006", "LA-0007", "LA-0008"]

# D-026 command / return bus.
COMMANDS_DIR = "docs/agent/commands"
RETURNS_DIR = "docs/agent/returns"
CMD_FIELDS = [
    "Command ID", "Sender", "Recipient", "Recorded by", "Source", "Issued", "Mission",
    "Tasks", "PR", "Head at issue", "Supersedes", "Executability change", "Gate evidence", "Status",
]
CMD_SECTIONS = ["Instruction", "Expected return"]
RET_FIELDS = [
    "Return ID", "Answers", "Sender", "Date", "Repository", "Branch", "Base SHA",
    "Head SHA", "PR", "Disposition", "Supersedes",
]
RET_SECTIONS = ["Work performed", "Tests / validation", "CI", "Deviations", "Blockers"]
RET_DISPOSITIONS = re.compile(r"^(READY_FOR_BRAIN_REVIEW|[A-Z_]+_READY_FOR_BRAIN_REVIEW|BLOCKED|PARTIAL|REJECTED_COMMAND)$")
CMD_PROCESSING_STATUSES = {"IDLE", "UNREAD", "ACKNOWLEDGED", "ANSWERED", "BLOCKED"}
LEDGER_STATUSES = {"ACKNOWLEDGED", "ANSWERED", "BLOCKED"}
STATE_BUS_KEYS = ["last_command_id", "last_acknowledged_command_id", "last_return_id", "command_processing_status"]
BRIDGE_STATUSES = {"VERIFIED_WORKING", "AUTO_AGENT_BRIDGE_BLOCKED"}

# CMD-0009: a committed file cannot contain the SHA of its own commit. A final-review record may
# therefore bind its head externally to the GitHub PR head instead of naming a literal SHA.
REVIEW_HEAD_SENTINEL = "PR_HEAD_AT_REVIEW"
REVIEW_HEAD_BINDING = "GITHUB_PR_HEAD"

# .claude/ may only carry Markdown rule files (no settings, agents, hooks, MCP).
CLAUDE_DIR_ALLOWED = re.compile(r"^\.claude/rules/[^/]+\.md$")

BRIDGE_WORKFLOW = ".github/workflows/claude-bridge.yml"
VALIDATION_WORKFLOW = ".github/workflows/bootstrap-validation.yml"


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
    for key in [
        "schema_version", "project", "repository", "mission", "lifecycle_stage", "status", "git",
        "next_handoff", "blockers", "protected_gate", "next_action", "canonical_source_refs",
        "updated_at", "auto_agent_bridge", *STATE_BUS_KEYS, "command_ledger",
    ]:
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
    head = git.get("head_sha")
    if head == REVIEW_HEAD_SENTINEL:
        r.check(status == "AWAITING_BRAIN_REVIEW",
                f"{rel}: git.head_sha {REVIEW_HEAD_SENTINEL} is only allowed when AWAITING_BRAIN_REVIEW")
        r.check(git.get("head_binding") == REVIEW_HEAD_BINDING,
                f"{rel}: git.head_sha {REVIEW_HEAD_SENTINEL} requires git.head_binding = {REVIEW_HEAD_BINDING}")
        for key in ["branch", "pr_number", "pr_url"]:
            r.check(git.get(key) not in (None, ""), f"{rel}: git.head_sha {REVIEW_HEAD_SENTINEL} requires git.{key}")
    elif head is not None:
        r.check(bool(sha_re.match(str(head))), f"{rel}: git.head_sha must be a 40-hex SHA")
    if status == "AWAITING_BRAIN_REVIEW":
        for key in ["head_sha", "pr_number", "pr_url"]:
            r.check(git.get(key) not in (None, ""), f"{rel}: git.{key} required when AWAITING_BRAIN_REVIEW")
    r.check(git.get("merged") is False, f"{rel}: git.merged must be false (agents do not merge)")

    nxt = state.get("next_handoff", {}) or {}
    r.check(bool(nxt.get("id")) and bool(nxt.get("status")), f"{rel}: next_handoff.id/status missing")

    bridge = state.get("auto_agent_bridge") or {}
    r.check(
        bridge.get("status") in BRIDGE_STATUSES,
        f"{rel}: auto_agent_bridge.status must be one of {sorted(BRIDGE_STATUSES)}",
    )
    if bridge.get("status") == "AUTO_AGENT_BRIDGE_BLOCKED":
        r.check(
            bool(bridge.get("missing_authorizations")),
            f"{rel}: AUTO_AGENT_BRIDGE_BLOCKED requires the exact missing_authorizations",
        )

    for task_id, s in (state.get("tasks") or {}).items():
        r.check(task_id in task_status, f"{rel}: task {task_id} not found in TASKS.md")
        if task_id in task_status:
            r.check(
                task_status[task_id] == s,
                f"{rel}: task {task_id} status '{s}' != TASKS.md '{task_status[task_id]}'",
            )
    for task_id in REQUIRED_TASKS:
        r.check(task_id in (state.get("tasks") or {}), f"{rel}: task {task_id} missing from tasks")


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
            # DONE milestones remain auditable history: keep validating their
            # task-to-plan pointers and plan contracts. Future non-executable
            # milestones still stop here because they intentionally have no
            # executable task/plan surface yet.
            if ms_status != "DONE":
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
            if r.check(sm is not None, f"{target}: missing **Status:** header"):
                r.check(sm.group(1) == status, f"{target}: status '{sm.group(1)}' != TASKS.md '{status}'")
            check_plan_contract(r, target, plan_text, fields.get("Depends on", ""),
                                require_quality=not ms.get("title", "").startswith("Milestone M0 "))

    for t in tasks:
        tid = t["title"].split(" ")[0]
        deps = t["fields"].get("Depends on", "")
        if deps.lower() != "none":
            for dep in re.findall(r"LA-\d{4}", deps):
                r.check(dep in ids, f"TASKS.md: {tid} depends on unknown task {dep}")

    for tid in REQUIRED_TASKS:
        r.check(tid in ids, f"TASKS.md: required bootstrap task {tid} missing")

    check_v0_skeleton(r, nodes)

    nm = re.search(r"Next unallocated ID: \*\*(LA-\d{4})\*\*", "\n".join(lines))
    if r.check(nm is not None, "TASKS.md: 'Next unallocated ID' line missing") and ids:
        r.check(
            nm.group(1) > max(ids),
            f"TASKS.md: next unallocated ID {nm.group(1)} must exceed highest used {max(ids)}",
        )
    return ids


def section_headings(text: str) -> list[str]:
    return [m.group(1).strip() for m in re.finditer(r"^## (.+)$", text, re.MULTILINE)]


def check_plan_contract(r: Report, rel: str, text: str, task_deps: str, require_quality: bool = False) -> None:
    """Every active plan carries the full D-019 / M3-E3 contract (+ D-029 section after bootstrap)."""
    heads = section_headings(text)
    for name in PLAN_SECTIONS + ([PLAN_QUALITY_SECTION] if require_quality else []):
        r.check(name in heads, f"{rel}: missing contract section '## {name}'")
    for label in ["Handoff", "Executor", "Owner / verifier"]:
        r.check(f"**{label}:**" in text, f"{rel}: missing **{label}:** header")
    dm = re.search(r"^## Dependencies\n(.*?)(?=^## |\Z)", text, re.MULTILINE | re.DOTALL)
    if dm:
        plan_deps = set(re.findall(r"LA-\d{4}", dm.group(1)))
        tasks_deps = set(re.findall(r"LA-\d{4}", task_deps))
        r.check(
            plan_deps == tasks_deps,
            f"{rel}: Dependencies {sorted(plan_deps)} != TASKS.md Depends on {sorted(tasks_deps)}",
        )


def check_v0_skeleton(r: Report, nodes: list[dict]) -> None:
    """Whole V0 program visible as PLANNED / NOT_EXECUTABLE milestone+sprint skeleton."""
    milestones = [n for n in nodes if n["level"] == 2]
    for name in V0_SKELETON:
        found = [m for m in milestones if name.lower() in m["title"].lower()]
        if not r.check(bool(found), f"TASKS.md: V0 skeleton milestone missing: {name}"):
            continue
        ms = found[0]
        if ms["fields"].get("Status") == "DONE":
            continue
        children = [n for n in nodes if n.get("milestone") is ms and n is not ms]
        sprints = [n for n in children if n["level"] == 3]
        executable = [
            n for n in children
            if n["level"] == 5 and n["fields"].get("Status") not in FUTURE_TASK_STATUSES
        ]
        r.check(bool(sprints), f"TASKS.md: V0 skeleton milestone '{name}' has no sprint skeleton")
        if ms["fields"].get("Status") != "ACTIVE":
            r.check(
                not executable,
                f"TASKS.md: V0 skeleton milestone '{name}' contains executable tasks",
            )
            for sp in sprints:
                s = sp["fields"].get("Status", "PLANNED / NOT_EXECUTABLE")
                r.check(
                    s == "PLANNED / NOT_EXECUTABLE",
                    f"TASKS.md:{sp['line']}: future sprint '{sp['title']}' must be PLANNED / NOT_EXECUTABLE",
                )


def check_reuse(r: Report) -> None:
    """D-024: register template/entries and AGENTS.md reuse-first rules."""
    if (ROOT / REGISTER).is_file():
        text = read_text(REGISTER)
        for name in REGISTER_FIELDS:
            r.check(f"| {name} |" in text, f"{REGISTER}: register field missing: {name}")
        for cls in REUSE_CLASSES:
            r.check(f"`{cls}`" in text, f"{REGISTER}: reuse class not defined: {cls}")
        # Real entries live outside fenced code blocks.
        unfenced = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
        ids: list[str] = []
        for m in re.finditer(r"^### (REUSE-\d{4}) — .+?$(.*?)(?=^### |^## |\Z)", unfenced, re.MULTILINE | re.DOTALL):
            rid, body = m.group(1), m.group(2)
            r.check(rid not in ids, f"{REGISTER}: duplicate entry {rid}")
            ids.append(rid)
            vals = dict(re.findall(r"^\| ([^|]+?) \| ([^|]*?) \|$", body, re.MULTILINE))
            for name in REGISTER_FIELDS:
                r.check(bool(vals.get(name, "").strip()), f"{REGISTER}: {rid} missing value for '{name}'")
            r.check(vals.get("Reuse class", "").strip() in REUSE_CLASSES, f"{REGISTER}: {rid} invalid reuse class")
            r.check(
                vals.get("Audit status", "").strip() in REUSE_AUDIT_STATUSES,
                f"{REGISTER}: {rid} invalid audit status",
            )
            r.check(
                bool(re.search(r"LA-\d{4}", vals.get("Task ID", ""))),
                f"{REGISTER}: {rid} Task ID must reference LA-####",
            )
        expected = [f"REUSE-{i:04d}" for i in range(1, len(ids) + 1)]
        r.check(ids == expected, f"{REGISTER}: entry IDs must be sequential from REUSE-0001, got {ids}")

    if (ROOT / "AGENTS.md").is_file():
        flat = " ".join(read_text("AGENTS.md").split())
        for cls in REUSE_CLASSES:
            r.check(f"`{cls}`" in flat, f"AGENTS.md: reuse class {cls} not defined")
        for phrase in AGENTS_REUSE_PHRASES:
            r.check(phrase in flat, f"AGENTS.md: D-024 reuse rule missing: '{phrase}'")
        for phrase in AGENTS_QUALITY_PHRASES:
            r.check(phrase in flat, f"AGENTS.md: D-029/D-028 quality projection missing: '{phrase}'")


def check_claude_dir(r: Report, files: list[str]) -> None:
    for rel in files:
        if rel.startswith(".claude/"):
            r.check(
                bool(CLAUDE_DIR_ALLOWED.match(rel)),
                f".claude scope: only .claude/rules/*.md may be tracked, found {rel}",
            )
        r.check(Path(rel).name != ".mcp.json", f"MCP configuration must not be tracked: {rel}")


def parse_record(text: str) -> tuple[str, dict[str, str], list[str]]:
    lines = text.splitlines()
    title = lines[0] if lines else ""
    fields = dict(re.findall(r"^- ([A-Za-z /]+): (.+)$", text, re.MULTILINE))
    return title, {k: v.strip() for k, v in fields.items()}, section_headings(text)


def record_num(rid: str | None) -> int:
    m = re.fullmatch(r"(?:CMD|RET)-(\d{4})", rid or "")
    return int(m.group(1)) if m else 0


def list_records(r: Report, files: list[str], folder: str, prefix: str) -> dict[str, str]:
    """Return {ID: rel path}; enforce naming and contiguous, never-reused numbering."""
    found: dict[str, str] = {}
    for rel in files:
        if not rel.startswith(folder + "/"):
            continue
        name = rel[len(folder) + 1:]
        if name == "README.md":
            continue
        if not r.check(
            bool(re.fullmatch(prefix + r"-\d{4}\.md", name)),
            f"{folder}: invalid {'command' if prefix == 'CMD' else 'return'} file name '{name}' (expected {prefix}-####.md)",
        ):
            continue
        found[name[:-3]] = rel
    nums = sorted(record_num(k) for k in found)
    r.check(
        nums == list(range(1, len(nums) + 1)),
        f"{folder}: {prefix} IDs must be contiguous from {prefix}-0001 (no gaps or reuse), got {sorted(found)}",
    )
    return found


def check_bus(r: Report, files: list[str], state: dict | None) -> None:
    """D-026 command / return bus: records, references, pointers, executability guard."""
    cmds = list_records(r, files, COMMANDS_DIR, "CMD")
    rets = list_records(r, files, RETURNS_DIR, "RET")
    nxt = (state or {}).get("next_handoff") or {}
    staged = nxt.get("id") if nxt.get("status") == "NOT_EXECUTABLE" else None
    sha_re = re.compile(r"^[0-9a-f]{40}$")

    cmd_meta: dict[str, dict[str, str]] = {}
    for cid, rel in sorted(cmds.items()):
        text = read_text(rel)
        title, f, heads = parse_record(text)
        cmd_meta[cid] = f
        r.check(title.startswith(f"# {cid} — "), f"{rel}: title must start with '# {cid} — '")
        for name in CMD_FIELDS:
            r.check(bool(f.get(name)), f"{rel}: missing field '{name}'")
        for name in CMD_SECTIONS:
            r.check(name in heads, f"{rel}: missing section '## {name}'")
        r.check(f.get("Command ID") == cid, f"{rel}: Command ID must equal {cid}")
        r.check(f.get("Sender") == "Brain", f"{rel}: Sender must be Brain (commands are Brain-owned)")
        r.check(f.get("Status") == "ISSUED", f"{rel}: Status must be ISSUED (processing state lives in EXECUTION_STATE.json)")
        sup = f.get("Supersedes", "none")
        if sup != "none":
            r.check(sup in cmds and record_num(sup) < record_num(cid), f"{rel}: Supersedes unknown/later command {sup}")
        head = f.get("Head at issue", "none")
        r.check(head == "none" or bool(sha_re.match(head)), f"{rel}: Head at issue must be a 40-hex SHA or none")

        # Executability guard: no silent admission of a staged handoff.
        change = f.get("Executability change", "")
        if change == "none":
            if staged and staged in text:
                r.check(
                    "NOT_EXECUTABLE" in text,
                    f"{rel}: executability guard: mentions staged {staged} without keeping it NOT_EXECUTABLE "
                    "(use an explicit 'Executability change' with PASS gate evidence)",
                )
        else:
            cm = re.fullmatch(r"([A-Z][A-Z0-9_-]*) -> (READY|EXECUTABLE)", change)
            if r.check(cm is not None, f"{rel}: executability guard: malformed Executability change '{change}'"):
                r.check(
                    "PASS" in f.get("Gate evidence", ""),
                    f"{rel}: executability guard: change to {cm.group(1)} lacks Brain PASS gate evidence",
                )
                r.check(
                    cm.group(1) != staged,
                    f"{rel}: executability guard: {cm.group(1)} still NOT_EXECUTABLE in EXECUTION_STATE.json / "
                    "CURRENT_HANDOFF.md; the change must land with reconciled state",
                )

    answered: dict[str, str] = {}
    covers: dict[str, set[str]] = {}
    partial: set[str] = set()
    superseded: set[str] = set()
    for rid, rel in sorted(rets.items()):
        text = read_text(rel)
        title, f, heads = parse_record(text)
        r.check(title.startswith(f"# {rid} — "), f"{rel}: title must start with '# {rid} — '")
        for name in RET_FIELDS:
            r.check(bool(f.get(name)), f"{rel}: missing field '{name}'")
        for name in RET_SECTIONS:
            r.check(name in heads, f"{rel}: missing section '## {name}'")
        r.check(f.get("Return ID") == rid, f"{rel}: Return ID must equal {rid}")
        ans = f.get("Answers", "")
        r.check(ans in cmds, f"{rel}: answers unknown command '{ans}'")
        answered[rid] = ans
        # CMD-0009 cumulative return: one final RET may also answer earlier commands it names explicitly.
        also = [c.strip() for c in f.get("Also answers", "").split(",") if c.strip()]
        for cid in also:
            r.check(cid in cmds and record_num(cid) < record_num(ans),
                    f"{rel}: Also answers '{cid}' must be an existing command earlier than {ans}")
        if also:
            r.check(f.get("Disposition") != "PARTIAL", f"{rel}: a PARTIAL checkpoint cannot declare Also answers")
        covers[rid] = {ans, *also}
        r.check(bool(RET_DISPOSITIONS.match(f.get("Disposition", ""))), f"{rel}: invalid Disposition")
        if f.get("Disposition") == "PARTIAL":
            partial.add(rid)
        r.check(bool(sha_re.match(f.get("Base SHA", ""))), f"{rel}: Base SHA must be a 40-hex SHA")
        if f.get("Head SHA") == REVIEW_HEAD_SENTINEL:
            r.check(f.get("Disposition", "").endswith("READY_FOR_BRAIN_REVIEW"),
                    f"{rel}: Head SHA {REVIEW_HEAD_SENTINEL} requires a READY_FOR_BRAIN_REVIEW disposition")
            r.check(f.get("Head binding") == REVIEW_HEAD_BINDING,
                    f"{rel}: Head SHA {REVIEW_HEAD_SENTINEL} requires 'Head binding: {REVIEW_HEAD_BINDING}'")
            if state is not None and rid == state.get("last_return_id"):
                git = state.get("git") or {}
                r.check(
                    state.get("status") == "AWAITING_BRAIN_REVIEW"
                    and git.get("head_sha") == REVIEW_HEAD_SENTINEL
                    and git.get("head_binding") == REVIEW_HEAD_BINDING,
                    f"{rel}: Head SHA {REVIEW_HEAD_SENTINEL} requires EXECUTION_STATE AWAITING_BRAIN_REVIEW with the "
                    f"same {REVIEW_HEAD_BINDING} binding",
                )
        else:
            r.check(bool(sha_re.match(f.get("Head SHA", ""))), f"{rel}: Head SHA must be a 40-hex SHA")
        sup = f.get("Supersedes", "none")
        if sup != "none":
            r.check(sup in rets and record_num(sup) < record_num(rid), f"{rel}: Supersedes unknown/later return {sup}")
            superseded.add(sup)

    if state is None:
        return
    rel = "docs/agent/EXECUTION_STATE.json"
    last_cmd = state.get("last_command_id")
    last_ack = state.get("last_acknowledged_command_id")
    last_ret = state.get("last_return_id")
    proc = state.get("command_processing_status")
    ledger = state.get("command_ledger") or {}
    max_cmd = max(cmds, key=record_num) if cmds else None
    max_ret = max(rets, key=record_num) if rets else None

    r.check(last_cmd == max_cmd, f"{rel}: last_command_id '{last_cmd}' != highest command file '{max_cmd}'")
    r.check(last_ret == max_ret, f"{rel}: last_return_id '{last_ret}' != highest return file '{max_ret}'")
    r.check(last_ack is None or last_ack in cmds, f"{rel}: last_acknowledged_command_id '{last_ack}' does not resolve")
    r.check(
        record_num(last_ack) <= record_num(last_cmd),
        f"{rel}: last_acknowledged_command_id '{last_ack}' is ahead of last_command_id '{last_cmd}'",
    )
    r.check(proc in CMD_PROCESSING_STATUSES, f"{rel}: command_processing_status '{proc}' invalid")

    for cid, entry in ledger.items():
        entry = entry or {}
        r.check(cid in cmds, f"{rel}: command_ledger entry {cid} has no command file")
        r.check(
            record_num(cid) <= record_num(last_ack),
            f"{rel}: command_ledger entry {cid} is beyond last_acknowledged_command_id",
        )
        st, ret = entry.get("status"), entry.get("return_id")
        r.check(st in LEDGER_STATUSES, f"{rel}: command_ledger[{cid}].status '{st}' invalid")
        if st in ("ANSWERED", "BLOCKED") or ret:
            r.check(ret in rets, f"{rel}: command_ledger[{cid}].return_id '{ret}' does not resolve")
            if ret in rets:
                r.check(cid in covers.get(ret, set()), f"{rel}: {ret} does not answer {cid}")
                r.check(ret not in partial, f"{rel}: command_ledger[{cid}].return_id {ret} is a PARTIAL checkpoint, not an answer")
        for pid in entry.get("partial_return_ids") or []:
            r.check(pid in partial and answered.get(pid) == cid,
                    f"{rel}: command_ledger[{cid}].partial_return_ids entry {pid} is not a PARTIAL return for {cid}")
    for n in range(1, record_num(last_ack) + 1):
        cid = f"CMD-{n:04d}"
        r.check(cid in ledger, f"{rel}: acknowledged command {cid} missing from command_ledger (no skipping)")
    for rid, cid in answered.items():
        entry = ledger.get(cid) or {}
        if rid in partial:
            r.check(rid in (entry.get("partial_return_ids") or []),
                    f"{rel}: PARTIAL {rid} for {cid} missing from command_ledger partial_return_ids")
        elif rid not in superseded:
            for covered in sorted(covers.get(rid, {cid})):
                e = ledger.get(covered) or {}
                r.check(e.get("status") in ("ANSWERED", "BLOCKED") and e.get("return_id") == rid,
                        f"{rel}: {rid} answers {covered} but command_ledger does not record it as answered")

    if record_num(last_cmd) > record_num(last_ack):
        expected = {"UNREAD"}
    elif not cmds:
        expected = {"IDLE"}
    else:
        sts = {(e or {}).get("status") for e in ledger.values()}
        if "ACKNOWLEDGED" in sts:
            expected = {"ACKNOWLEDGED"}
        elif "BLOCKED" in sts:
            expected = {"BLOCKED"}
        else:
            expected = {"ANSWERED", "IDLE"}
    r.check(proc in expected, f"{rel}: command_processing_status '{proc}' inconsistent with pointers (expected {sorted(expected)})")


def check_workflows(r: Report) -> None:
    if (ROOT / VALIDATION_WORKFLOW).is_file():
        wf = read_text(VALIDATION_WORKFLOW)
        r.check("contents: read" in wf and "write" not in wf, f"{VALIDATION_WORKFLOW}: must be read-only")
        r.check("secrets." not in wf, f"{VALIDATION_WORKFLOW}: must not use secrets")
        r.check("test_validate_bootstrap.py" in wf, f"{VALIDATION_WORKFLOW}: must run the negative-test suite")
    if (ROOT / BRIDGE_WORKFLOW).is_file():
        wf = read_text(BRIDGE_WORKFLOW)
        r.check(re.search(r"^permissions: \{\}$", wf, re.MULTILINE) is not None,
                f"{BRIDGE_WORKFLOW}: workflow-level permissions must be {{}}")
        r.check("vars.CLAUDE_BRIDGE_ENABLED == 'true'" in wf, f"{BRIDGE_WORKFLOW}: missing enable/kill-switch guard")
        r.check(wf.count("author_association") >= 4, f"{BRIDGE_WORKFLOW}: missing trusted-role guard on every trigger")
        for bad in ["allowed_non_write_users", "pull_request_target", "anthropic_api_key", "allowed_bots"]:
            r.check(bad not in wf, f"{BRIDGE_WORKFLOW}: forbidden setting '{bad}'")
        for perm in re.findall(r"^\s+([a-z-]+): write", wf, re.MULTILINE):
            r.check(perm in {"contents", "pull-requests", "issues", "id-token"},
                    f"{BRIDGE_WORKFLOW}: unexpected write permission '{perm}'")
        for sec in re.findall(r"secrets\.([A-Z_]+)", wf):
            r.check(sec in {"CLAUDE_CODE_OAUTH_TOKEN", "GITHUB_TOKEN"}, f"{BRIDGE_WORKFLOW}: unexpected secret {sec}")
        r.check("CURRENT_HANDOFF.md" in wf and "CMD-" in wf,
                f"{BRIDGE_WORKFLOW}: wake-up prompt must require the handoff/command read")


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
    check_reuse(r)
    check_claude_dir(r, files)
    check_bus(r, files, state)
    check_workflows(r)

    if r.failures:
        print(f"FAIL: {len(r.failures)} of {r.checks} checks failed")
        for msg in r.failures:
            print(f"  - {msg}")
        return 1
    print(f"OK: {r.checks} checks passed across {len(files)} files, {len(task_status)} tasks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
