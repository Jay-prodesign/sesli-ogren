# Provenance

Origin records for anything in this repository not authored from scratch for it:
third-party code, dependencies, assets (audio, images, fonts), datasets, and
generated content.

| Surface | Use |
| --- | --- |
| [`OPEN_SOURCE_REUSE_REGISTER.md`](OPEN_SOURCE_REUSE_REGISTER.md) | **Mandatory** D-024 register for every material code/module/dependency reuse, including reuse class, exact version, licence, notice obligations, and approving task/decision. |
| `PROV-####-short-title.md` (optional) | Longer audit notes for a single register entry, such as an asset or dataset or a complex adaptation. Always link it from the register. |

**Current state:** no imported material. All bootstrap files were authored for
this repository under CLAUDE_HANDOFF_000. Donor code is prohibited unless an
admitted task authorizes it (see [`AGENTS.md` §12](../../AGENTS.md#12-open-source-reuse-d-024)).

## CI tooling referenced, not vendored

| Tool | Reference | Used by | Notes |
| --- | --- | --- | --- |
| `actions/checkout` | `@v5` (major tag) | both workflows | Official GitHub action. Not copied. |
| `anthropics/claude-code-action` | `@v1` (major tag) | `.github/workflows/claude-bridge.yml` | Official Anthropic action (LA-0008 wake-up bridge). Not copied. The workflow does not run until the Product Owner activates it. |
