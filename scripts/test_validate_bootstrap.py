#!/usr/bin/env python3
"""Negative tests for scripts/validate_bootstrap.py (standard library only).

Each test copies the repository control plane into a temporary Git work tree,
applies one violation, runs the validator there, and asserts that it fails
with the expected message. The baseline test asserts that the unmodified copy
passes. Run:

    python3 scripts/test_validate_bootstrap.py
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATE = "docs/agent/EXECUTION_STATE.json"

# Built at runtime so this file never matches the validator's own scans.
FAKE_AWS_KEY = "AK" + "IA" + "Q" * 16
FAKE_HOME_PATH = "/ho" + "me/alice/project"


def tracked_files() -> list[str]:
    out = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT, check=True, capture_output=True,
    ).stdout.decode("utf-8")
    return [f for f in out.split("\0") if f and (ROOT / f).is_file()]


def valid_cmd(num: int, *, change: str = "none", gate: str = "none", body: str = "Routine instruction.") -> str:
    return (
        f"# CMD-{num:04d} — Test command\n\n"
        f"- Command ID: CMD-{num:04d}\n- Sender: Brain\n- Recipient: Claude (Primary Engineer)\n"
        "- Recorded by: Brain\n- Source: test\n- Issued: 2026-09-28\n- Mission: CLAUDE_HANDOFF_000\n"
        "- Tasks: LA-0008\n- PR: #1\n- Head at issue: none\n- Supersedes: none\n"
        f"- Executability change: {change}\n- Gate evidence: {gate}\n- Status: ISSUED\n\n"
        f"## Instruction\n\n{body}\n\n## Expected return\n\nA RET.\n"
    )


class ValidatorNegativeTests(unittest.TestCase):
    files: list[str] = []

    @classmethod
    def setUpClass(cls) -> None:
        cls.files = tracked_files()

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        for rel in self.files:
            dst = self.root / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / rel, dst)
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    # --- helpers -----------------------------------------------------------
    def run_validator(self) -> tuple[int, str]:
        proc = subprocess.run(
            [sys.executable, str(self.root / "scripts/validate_bootstrap.py")],
            cwd=self.root, capture_output=True, text=True, encoding="utf-8",
        )
        return proc.returncode, proc.stdout + proc.stderr

    def write(self, rel: str, text: str) -> None:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def edit(self, rel: str, old: str, new: str) -> None:
        path = self.root / rel
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text, f"test setup: '{old}' not in {rel}")
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    def state(self) -> dict:
        return json.loads((self.root / STATE).read_text(encoding="utf-8"))

    def set_state(self, **changes) -> None:
        s = self.state()
        s.update(changes)
        self.write(STATE, json.dumps(s, indent=2, ensure_ascii=False) + "\n")

    def staged(self) -> str:
        return self.state()["next_handoff"]["id"]

    def next_cmd_num(self) -> int:
        return max(int(p.stem[4:]) for p in (self.root / "docs/agent/commands").glob("CMD-*.md")) + 1

    def add_unread_cmd(self, **kw) -> None:
        """Add a well-formed next command and keep pointers reconciled (UNREAD)."""
        n = self.next_cmd_num()
        self.write(f"docs/agent/commands/CMD-{n:04d}.md", valid_cmd(n, **kw))
        self.set_state(last_command_id=f"CMD-{n:04d}", command_processing_status="UNREAD")

    def assertFailsWith(self, pattern: str) -> None:
        code, out = self.run_validator()
        self.assertNotEqual(code, 0, f"validator unexpectedly passed:\n{out}")
        self.assertRegex(out, pattern, f"expected failure /{pattern}/ not reported:\n{out}")

    # --- baseline ----------------------------------------------------------
    def test_baseline_passes(self) -> None:
        code, out = self.run_validator()
        self.assertEqual(code, 0, out)

    def test_well_formed_unread_command_passes(self) -> None:
        self.add_unread_cmd()
        code, out = self.run_validator()
        self.assertEqual(code, 0, out)

    # --- secrets / hygiene -------------------------------------------------
    def test_env_file(self) -> None:
        self.write(".env.local", "X=1\n")
        subprocess.run(["git", "add", "-f", ".env.local"], cwd=self.root, check=True)
        self.assertFailsWith(r"forbidden secret-bearing file present: \.env\.local")

    def test_secret_token(self) -> None:
        self.write("docs/qa/note.md", f"key {FAKE_AWS_KEY}\n")
        self.assertFailsWith(r"possible AWS access key ID")

    def test_personal_path(self) -> None:
        self.write("docs/qa/note.md", f"see {FAKE_HOME_PATH}\n")
        self.assertFailsWith(r"Unix home path found")

    def test_invalid_state_json(self) -> None:
        self.write(STATE, "{ not json\n")
        self.assertFailsWith(r"EXECUTION_STATE\.json does not parse")

    # --- D-024 reuse -------------------------------------------------------
    def test_register_missing(self) -> None:
        (self.root / "docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md").unlink()
        self.assertFailsWith(r"required file missing: docs/provenance/OPEN_SOURCE_REUSE_REGISTER\.md")

    def test_register_field_missing(self) -> None:
        path = self.root / "docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md"
        path.write_text(path.read_text(encoding="utf-8").replace("| Approving decision / task |", "| Approver |"),
                        encoding="utf-8")
        self.assertFailsWith(r"register field missing: Approving decision / task")

    def test_register_entry_value_missing(self) -> None:
        self.edit("docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md",
                  "| Exact tag / commit / version | main @ 317e21df9587a2ba6337e9802ae4119ad9b5e2e5 |",
                  "| Exact tag / commit / version |  |")
        self.assertFailsWith(r"REUSE-0001 missing value for 'Exact tag / commit / version'")

    def test_register_entry_invalid_class(self) -> None:
        entry = (
            "\n### REUSE-0001 — Example\n\n| Field | Value |\n| --- | --- |\n"
            "| Task ID | LA-0008 |\n| Upstream repository | https://example.org/x |\n"
            "| Exact tag / commit / version | v1 |\n| License | MIT |\n| Reuse class | FORK |\n"
            "| Dependency / files / modules used | x |\n| Material modifications | none |\n"
            "| Copyright / license / NOTICE obligations | keep |\n| Audit status | APPROVED |\n"
            "| Approving decision / task | D-024 |\n"
        )
        path = self.root / "docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md"
        path.write_text(path.read_text(encoding="utf-8") + entry, encoding="utf-8")
        self.assertFailsWith(r"REUSE-0001 invalid reuse class")

    def test_agents_reuse_class_missing(self) -> None:
        self.edit("AGENTS.md", "| `PATTERN-ONLY` |", "| `REFERENCE` |")
        self.assertFailsWith(r"AGENTS\.md: reuse class PATTERN-ONLY not defined")

    def test_agents_no_rewrite_rule_missing(self) -> None:
        self.edit("AGENTS.md", "internally authored", "ours")
        self.assertFailsWith(r"D-024 reuse rule missing")

    # --- .claude scope -----------------------------------------------------
    def test_claude_settings_forbidden(self) -> None:
        self.write(".claude/settings.json", "{}\n")
        self.assertFailsWith(r"\.claude scope: only \.claude/rules/\*\.md may be tracked")

    def test_claude_agents_forbidden(self) -> None:
        self.write(".claude/agents/helper.md", "# helper\n")
        self.assertFailsWith(r"\.claude scope")

    # --- TASKS / plans / skeleton -----------------------------------------
    def test_hierarchy_break(self) -> None:
        self.edit("TASKS.md", "#### Section M0.S1.A — Pre-flight and identity\n", "")
        self.assertFailsWith(r"hierarchy break")

    def test_plan_contract_section_missing(self) -> None:
        self.edit("docs/exec-plans/LA-0010.md", "## Escalation conditions", "## Notes")
        self.assertFailsWith(r"LA-0010\.md: missing contract section '## Escalation conditions'")

    def test_plan_quality_section_missing(self) -> None:
        self.edit("docs/exec-plans/LA-0013.md", "## Quality considerations (D-029)", "## Notes")
        self.assertFailsWith(r"LA-0013\.md: missing contract section '## Quality considerations \(D-029\)'")

    def test_agents_quality_projection_missing(self) -> None:
        path = self.root / "AGENTS.md"
        path.write_text(path.read_text(encoding="utf-8").replace("Final Engineering Test", "final check"), encoding="utf-8")
        self.assertFailsWith(r"AGENTS\.md: D-029/D-028 quality projection missing: 'Final Engineering Test'")

    def test_plan_dependency_mismatch(self) -> None:
        self.edit("docs/exec-plans/LA-0012.md", "## Dependencies\n- LA-0011\n", "## Dependencies\n- LA-0001\n")
        self.assertFailsWith(r"LA-0012\.md: Dependencies .* != TASKS\.md Depends on")

    def test_broken_plan_pointer(self) -> None:
        self.edit("TASKS.md", "(docs/exec-plans/LA-0011.md)", "(docs/exec-plans/LA-0099.md)")
        self.assertFailsWith(r"LA-0011 exec plan pointer")

    def test_v0_skeleton_milestone_missing(self) -> None:
        self.edit("TASKS.md", "## Milestone M6 — Controlled Public V0 Release", "## Milestone M6 — Something Else")
        self.assertFailsWith(r"V0 skeleton milestone missing: Controlled Public V0 Release")

    def test_future_task_executable(self) -> None:
        self.edit("TASKS.md", "### Sprint M2.S1 — Slice foundation\n",
                  "### Sprint M2.S1 — Slice foundation\n\n#### Section M2.S1.A — X\n\n"
                  "##### LA-0018 — Premature task\n\n- Status: READY\n- Depends on: none\n"
                  "- Owner: Brain\n- Executor: Claude\n- Verification: x\n- Exec plan: none\n")
        self.edit("TASKS.md", "**LA-0018**", "**LA-0019**")
        self.assertFailsWith(r"LA-0018 is executable under non-active milestone")

    def test_la0008_missing(self) -> None:
        self.edit("TASKS.md", "##### LA-0008 — ", "##### LA-0009 — ")
        self.assertFailsWith(r"required bootstrap task LA-0008 missing")

    # --- D-026 command / return bus ---------------------------------------
    def test_bad_command_name(self) -> None:
        self.write("docs/agent/commands/cmd-2.md", "# bad\n")
        self.assertFailsWith(r"invalid command file name 'cmd-2\.md'")

    def test_command_id_gap(self) -> None:
        n = self.next_cmd_num() + 1  # skip one number
        self.write(f"docs/agent/commands/CMD-{n:04d}.md", valid_cmd(n))
        self.set_state(last_command_id=f"CMD-{n:04d}", command_processing_status="UNREAD")
        self.assertFailsWith(r"CMD IDs must be contiguous")

    def test_command_pointer_drift(self) -> None:
        n = self.next_cmd_num()
        self.write(f"docs/agent/commands/CMD-{n:04d}.md", valid_cmd(n))
        self.assertFailsWith(r"last_command_id '.*' != highest command file")

    def test_ack_ahead_of_command(self) -> None:
        self.set_state(last_acknowledged_command_id="CMD-0050")
        self.assertFailsWith(r"last_acknowledged_command_id 'CMD-0050' (does not resolve|is ahead)")

    def test_unread_status_inconsistent(self) -> None:
        self.add_unread_cmd()
        self.set_state(command_processing_status="ANSWERED")
        self.assertFailsWith(r"command_processing_status 'ANSWERED' inconsistent")

    def test_return_answers_unknown_command(self) -> None:
        ret = (self.root / "docs/agent/returns/RET-0001.md").read_text(encoding="utf-8")
        ret = ret.replace("RET-0001", "RET-0002").replace("- Answers: CMD-0001", "- Answers: CMD-0099")
        self.write("docs/agent/returns/RET-0002.md", ret)
        self.set_state(last_return_id="RET-0002")
        self.assertFailsWith(r"answers unknown command 'CMD-0099'")

    def test_return_pointer_drift(self) -> None:
        self.set_state(last_return_id=None)
        self.assertFailsWith(r"last_return_id 'None' != highest return file")

    def test_ledger_return_mismatch(self) -> None:
        s = self.state()
        s["command_ledger"]["CMD-0001"]["return_id"] = "RET-0007"
        self.write(STATE, json.dumps(s, indent=2) + "\n")
        self.assertFailsWith(r"command_ledger\[CMD-0001\]\.return_id 'RET-0007' does not resolve")

    def test_command_not_brain_owned(self) -> None:
        self.add_unread_cmd()
        n = self.next_cmd_num() - 1
        self.edit(f"docs/agent/commands/CMD-{n:04d}.md", "- Sender: Brain", "- Sender: Claude")
        self.assertFailsWith(r"Sender must be Brain")

    def test_guard_explicit_change_without_pass(self) -> None:
        self.add_unread_cmd(change="CLAUDE_HANDOFF_001 -> READY", gate="none")
        self.assertFailsWith(r"executability guard: change to CLAUDE_HANDOFF_001 lacks Brain PASS")

    def test_guard_explicit_change_without_reconciled_state(self) -> None:
        staged = self.staged()
        self.add_unread_cmd(change=f"{staged} -> READY", gate="Brain review BOOTSTRAP_PASS")
        self.assertFailsWith(rf"executability guard: {staged} still NOT_EXECUTABLE")

    def test_guard_silent_admission(self) -> None:
        staged = self.staged()
        self.add_unread_cmd(body=f"Begin {staged} now.")
        self.assertFailsWith(rf"executability guard: mentions staged {staged}")

    def test_partial_return_not_in_ledger(self) -> None:
        s = self.state()
        s["command_ledger"]["CMD-0002"]["partial_return_ids"] = []
        self.write(STATE, json.dumps(s, indent=2) + "\n")
        self.assertFailsWith(r"PARTIAL RET-0002 for CMD-0002 missing from command_ledger partial_return_ids")

    def test_partial_return_used_as_answer(self) -> None:
        s = self.state()
        s["command_ledger"]["CMD-0002"].update(status="ANSWERED", return_id="RET-0002")
        s["command_processing_status"] = "ANSWERED"
        self.write(STATE, json.dumps(s, indent=2) + "\n")
        self.assertFailsWith(r"RET-0002 is a PARTIAL checkpoint, not an answer")

    # --- CMD-0009 external head binding / cumulative return ---------------
    RET5 = "docs/agent/returns/RET-0005.md"
    LITERAL = "0123456789abcdef0123456789abcdef01234567"

    def set_git(self, **changes) -> None:
        s = self.state()
        for k, v in changes.items():
            if v is None:
                s["git"].pop(k, None)
            else:
                s["git"][k] = v
        self.write(STATE, json.dumps(s, indent=2, ensure_ascii=False) + "\n")

    def test_head_sentinel_outside_review_state(self) -> None:
        self.set_git(head_sha="PR_HEAD_AT_REVIEW", head_binding="GITHUB_PR_HEAD")
        self.set_state(status="IN_PROGRESS")
        self.assertFailsWith(r"git\.head_sha PR_HEAD_AT_REVIEW is only allowed when AWAITING_BRAIN_REVIEW")

    def test_head_sentinel_missing_binding(self) -> None:
        self.set_state(status="AWAITING_BRAIN_REVIEW")
        self.set_git(head_sha="PR_HEAD_AT_REVIEW", head_binding=None)
        self.assertFailsWith(r"requires git\.head_binding = GITHUB_PR_HEAD")

    def test_head_sentinel_wrong_binding(self) -> None:
        self.set_state(status="AWAITING_BRAIN_REVIEW")
        self.set_git(head_sha="PR_HEAD_AT_REVIEW", head_binding="LOCAL_GUESS")
        self.assertFailsWith(r"requires git\.head_binding = GITHUB_PR_HEAD")

    def test_head_sentinel_missing_pr_metadata(self) -> None:
        self.set_state(status="AWAITING_BRAIN_REVIEW")
        self.set_git(head_sha="PR_HEAD_AT_REVIEW", head_binding="GITHUB_PR_HEAD", pr_url="")
        self.assertFailsWith(r"git\.head_sha PR_HEAD_AT_REVIEW requires git\.pr_url")

    def test_head_arbitrary_non_hex(self) -> None:
        self.set_git(head_sha="PR_HEAD_LATER")
        self.assertFailsWith(r"git\.head_sha must be a 40-hex SHA")

    def test_ret_sentinel_non_review_disposition(self) -> None:
        self.edit(self.RET5, "- Disposition: READY_FOR_BRAIN_REVIEW", "- Disposition: BLOCKED")
        self.assertFailsWith(r"RET-0005\.md: Head SHA PR_HEAD_AT_REVIEW requires a READY_FOR_BRAIN_REVIEW disposition")

    def test_ret_sentinel_missing_binding(self) -> None:
        self.edit(self.RET5, "- Head binding: GITHUB_PR_HEAD\n", "")
        self.assertFailsWith(r"RET-0005\.md: Head SHA PR_HEAD_AT_REVIEW requires 'Head binding: GITHUB_PR_HEAD'")

    def test_ret_sentinel_state_literal_head(self) -> None:
        latest = "docs/agent/returns/RET-0006.md"
        self.edit(latest, "- Head SHA: 0327d2e5b854df1c9923c65ed88f77151cfe9eed",
                  "- Head SHA: PR_HEAD_AT_REVIEW\n- Head binding: GITHUB_PR_HEAD")
        self.set_git(head_sha=self.LITERAL, head_binding=None)
        self.assertFailsWith(r"RET-0006\.md: Head SHA PR_HEAD_AT_REVIEW requires EXECUTION_STATE AWAITING_BRAIN_REVIEW")

    def test_literal_heads_still_pass(self) -> None:
        self.set_git(head_sha=self.LITERAL, head_binding=None)
        self.edit(self.RET5, "- Head SHA: PR_HEAD_AT_REVIEW", f"- Head SHA: {self.LITERAL}")
        code, out = self.run_validator()
        self.assertEqual(code, 0, out)

    def test_also_answers_later_command(self) -> None:
        self.edit(self.RET5, "- Also answers: CMD-0004,", "- Also answers: CMD-0099, CMD-0004,")
        self.assertFailsWith(r"Also answers 'CMD-0099' must be an existing command earlier than CMD-0013")

    def test_also_answers_not_in_ledger(self) -> None:
        s = self.state()
        s["command_ledger"]["CMD-0004"] = {"status": "ACKNOWLEDGED", "return_id": None}
        self.write(STATE, json.dumps(s, indent=2, ensure_ascii=False) + "\n")
        self.assertFailsWith(r"RET-0005 answers CMD-0004 but command_ledger does not record it as answered")

    def test_partial_return_with_also_answers(self) -> None:
        self.edit("docs/agent/returns/RET-0002.md", "- Supersedes:", "- Also answers: CMD-0001\n- Supersedes:")
        self.assertFailsWith(r"RET-0002\.md: a PARTIAL checkpoint cannot declare Also answers")

    # --- workflows ---------------------------------------------------------
    def test_bridge_non_write_users(self) -> None:
        self.edit(".github/workflows/claude-bridge.yml", "          claude_args: |",
                  "          allowed_non_write_users: '*'\n          claude_args: |")
        self.assertFailsWith(r"claude-bridge\.yml: forbidden setting 'allowed_non_write_users'")

    def test_bridge_kill_switch_removed(self) -> None:
        self.edit(".github/workflows/claude-bridge.yml", "vars.CLAUDE_BRIDGE_ENABLED == 'true' && ", "")
        self.assertFailsWith(r"missing enable/kill-switch guard")

    def test_validation_workflow_write_permission(self) -> None:
        self.edit(".github/workflows/bootstrap-validation.yml", "contents: read", "contents: write")
        self.assertFailsWith(r"bootstrap-validation\.yml: must be read-only")


if __name__ == "__main__":
    unittest.main(verbosity=2)
