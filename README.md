# Sesli Öğren

Engineering repository for **Sesli Öğren**, internally tracked as the **Learning App** project.

> **Status: repository bootstrap (Milestone 0).** This repository contains only
> engineering governance, agent contracts, the task map, and lightweight bootstrap
> validation. **No application code exists yet**, and none may be added until a
> Brain-approved handoff makes a product task executable.

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
| [`docs/exec-plans/`](docs/exec-plans/) | One executable plan per active task |
| [`docs/architecture/`](docs/architecture/) | Architecture notes (empty until approved) |
| [`docs/adr/`](docs/adr/) | Architecture Decision Records |
| [`docs/provenance/`](docs/provenance/) | Origin records for any imported code/assets |
| [`docs/qa/`](docs/qa/) | QA plans and evidence |
| [`scripts/`](scripts/) | Repository validation scripts |
| [`.github/workflows/`](.github/workflows/) | CI |

## Validation

Bootstrap validation needs only Python 3 (standard library) and Git:

```sh
python3 scripts/validate_bootstrap.py
```

CI runs the same check on every pull request and on pushes to `main`.

## Licensing

No license has been granted for this repository at this time. A licensing decision
is a product-authority matter and is out of scope for the bootstrap.
