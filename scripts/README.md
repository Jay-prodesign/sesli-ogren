# scripts

Repository tooling. No application build or test scripts exist yet.

| Script | Purpose | Requirements |
| --- | --- | --- |
| `validate_bootstrap.py` | Validates the engineering control plane. It checks required files and directories; readable UTF-8 control text; forbidden secret-bearing files, obvious secret tokens, and local user paths; `CLAUDE.md` / `AGENTS.md` contract content, including the full read order, the D-024 reuse classes and rules, and the D-026 bus rules; the `OPEN_SOURCE_REUSE_REGISTER.md` fields and any entries; that `.claude/` holds only `rules/*.md`; the `TASKS.md` hierarchy, IDs, fields, statuses, dependencies, and required LA-0001…LA-0008; the whole-V0 skeleton (M1…M7 PLANNED / NOT_EXECUTABLE with sprints); exec-plan pointers, statuses, full contract sections, and dependency reconciliation; the `EXECUTION_STATE.json` schema and its consistency with `TASKS.md`; CMD/RET naming, contiguous non-reused IDs, required fields, and RET → CMD references; pointer and ledger reconciliation; the executability guard against silently admitting a staged handoff; `CURRENT_HANDOFF.md` staging; and workflow permission and bridge safety. | Python 3.9+ (standard library), Git |
| `test_validate_bootstrap.py` | Negative-test suite (stdlib `unittest`). Copies the tree into a temporary Git work tree, applies one violation per test, and asserts the validator fails with the expected message. The baseline copy must pass. | Python 3.9+, Git |

```sh
python3 scripts/validate_bootstrap.py
python3 scripts/test_validate_bootstrap.py
```

The validator scans tracked files plus untracked files that are not ignored.
It is a guard rail, not a full secret scanner. The executability guard is also
a guard rail: Brain review remains the authority.
