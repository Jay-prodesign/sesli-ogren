# Sesli Öğren

Engineering repository for **Sesli Öğren**, internally tracked as the **Learning App** project.

> **Status: M4 Architecture Proof (TASKS.md milestone M1).** On the
> `spike/v0-architecture-proof` branch (draft PR #2, unmerged), proof-only code
> lives under [`spike/architecture-proof/`](spike/architecture-proof/). It is
> evidence for an architecture decision, not product code. **Full V0 implementation
> is not admitted**; product work starts only after Brain admits a later handoff.

## Where truth lives

| Concern | Source of truth |
| --- | --- |
| Product intent, scope, decisions, lifecycle gates | Private Google Drive governance set (not mirrored here) |
| Engineering state: code, task map, execution plans, evidence | This GitHub repository |

This repository is **public**. Private Drive content is never copied here — only
titles and decision identifiers may be referenced.

## Repository map

| Path | Purpose |
| --- | --- |
| [`AGENTS.md`](AGENTS.md) | Roles, authority, and operating rules for every agent |
| [`CLAUDE.md`](CLAUDE.md) | Primary Engineer (Claude) entry point and mandatory read order |
| [`TASKS.md`](TASKS.md) | Task map: Milestone → Sprint → Section → Task (`LA-####`) |
| [`docs/agent/`](docs/agent/) | Live handoff, engineer return, decision requests, execution state |
| [`docs/agent/commands/`](docs/agent/commands/) · [`docs/agent/returns/`](docs/agent/returns/) | Brain → Engineer command records (`CMD-####`) and Engineer → Brain returns (`RET-####`) |
| [`.claude/rules/`](.claude/rules/) | Small project rules for Claude Code (no settings/hooks/MCP) |
| [`docs/exec-plans/`](docs/exec-plans/) | One executable plan per active task |
| [`docs/architecture/`](docs/architecture/) | Architecture notes, including the Architecture Proof evidence under `spike/` |
| [`docs/adr/`](docs/adr/) | Architecture Decision Records |
| [`docs/provenance/`](docs/provenance/) | Origin records; [`OPEN_SOURCE_REUSE_REGISTER.md`](docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md) (D-024) |
| [`docs/qa/`](docs/qa/) | QA plans and evidence |
| [`scripts/`](scripts/) | Repository validation scripts |
| [`.github/workflows/`](.github/workflows/) | CI (`bootstrap-validation`, `spike-proof` for SQL + Deno, `flutter-proof` for the proof client) and the inert Claude wake-up bridge (`claude-bridge`) |

## Validation

Bootstrap validation needs only Python 3 (standard library) and Git:

```sh
python3 scripts/validate_bootstrap.py        # control-plane validation
python3 scripts/test_validate_bootstrap.py   # validator negative tests
```

CI runs both on every pull request and on pushes to `main`.

### Architecture Proof Flutter client

The repository Flutter SDK pin is [`.flutter-version`](.flutter-version) (`3.47.5`, Dart 3.13.4).

```sh
cd spike/architecture-proof/client
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

The SQL and Deno proofs are described in [`spike/architecture-proof/README.md`](spike/architecture-proof/README.md).

## Licensing

No license has been granted for this repository at this time. A licensing decision
is a product-authority matter and is out of scope for the bootstrap.
