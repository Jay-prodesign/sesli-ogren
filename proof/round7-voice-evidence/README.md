# Round 7 Turkish Voice Evidence Tooling

Scope: R7-07A evidence-quality helpers only. These tools are provider-neutral and
standard-library only. They do not call a TTS provider, consume credentials or
credits, rank candidates, select a provider/voice, or grant R7-07 PASS.

## Per-sample record

Copy `VOICE_SAMPLE_TEMPLATE.json`, fill it after generating a real Turkish audio
sample, then run:

```sh
python3 validate_voice_sample.py sample-V01.json
```

The check enforces blind sample IDs, hidden provider identity for listeners,
Turkish locale, corpus version/item A-L, input-text SHA-256, provenance,
ISO-8601 generation time, latency, cost/credit recording, raw metadata/audio
locations and audio SHA-256. The private canonical corpus text stays in Drive;
the public repository stores only generic validators/templates.

After all samples for the candidate set exist, validate cross-candidate
comparability:

```sh
python3 validate_voice_benchmark.py samples/*.json
```

Each candidate key must contain canonical corpus A-L exactly once, with unique
blind IDs and consistent corpus version, locale, requested audio format and
synthesis mode/quality tier. For each A-L item, all candidates must also carry
the same input-text SHA-256 and character count. This catches private-corpus
mutation or non-comparable benchmark sets without publishing corpus text or
ranking candidates.

## Blind listening panel

Copy `LISTENING_PANEL_TEMPLATE.json`, add the actual blind sample IDs and native
or near-native Turkish listeners, then run:

```sh
python3 validate_listening_panel.py panel.json
```

The check enforces complete 1-5 ratings across the canonical dimensions, sample
order coverage, critical-defect recording and provider blinding. It deliberately
refuses automated winner/ranking semantics.

## Important boundary

R7-07A still requires real audio, native/near-native Turkish human listening,
measured latency/cost and privacy/security/license review. R7-07B still requires
the parity-qualified Companion visual/state system and timing/failure coherence.
These tools only reduce evidence-packaging error.
