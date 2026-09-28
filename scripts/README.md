# scripts

Repository tooling. No application build or test scripts exist yet.

| Script | Purpose | Requirements |
| --- | --- | --- |
| `validate_bootstrap.py` | Validates the engineering control plane: required files/dirs, readable UTF-8 control text, `EXECUTION_STATE.json` schema and consistency with `TASKS.md`, forbidden secret-bearing files, obvious secret tokens and local user paths, `CLAUDE.md`/`AGENTS.md` contract content, `CURRENT_HANDOFF.md` staging, `TASKS.md` hierarchy / IDs / fields / statuses / dependencies, and Milestone 0 exec-plan pointer resolution. | Python 3.9+ (standard library), Git |

```sh
python3 scripts/validate_bootstrap.py
```

The script scans tracked files plus untracked files that are not ignored.
It is a guard rail, not a full secret scanner.
