# .claude/rules

Small, stable project rules that Claude Code loads alongside `CLAUDE.md`. They
restate constraints from `AGENTS.md` in operational form. **They add no
authority.** If a rule here ever disagrees with `AGENTS.md`, `AGENTS.md` wins,
and the rule must be fixed.

The validator (`scripts/validate_bootstrap.py`) enforces the scope. This
directory may contain only Markdown rule files. Settings, agents, hooks,
commands, skills, MCP configuration, credentials, and machine-specific paths do
not belong in tracked `.claude/`.
