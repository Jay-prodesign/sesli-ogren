# Round 7 Turkish Voice Evidence Tooling

Scope: R7-07A evidence-quality helpers only. These tools are provider-neutral and
standard-library only. They do not call a TTS provider, consume credentials or
credits, rank candidates, select a provider/voice, or grant R7-07 PASS.

## Candidate classes

R7-07A may compare three evidence classes under the same canonical Turkish A-L
corpus and blind listening gate:

- `native_os`: physical iOS or Android system/on-device TTS;
- `self_hosted`: an approved local/self-hosted model/runtime;
- `hosted_cloud`: an external hosted TTS service.

Native/on-device candidates are first-class candidates, not automatic winners.
A zero metered-provider cost does not prove product quality, total operating cost,
commercial suitability or production selection.

## Per-sample record

Copy `VOICE_SAMPLE_TEMPLATE.json`, fill it after generating a real Turkish audio
sample, then run:

```sh
python3 validate_voice_sample.py sample-V01.json
```

Schema v2 enforces blind sample IDs, hidden provider identity for listeners,
Turkish locale, corpus version/item A-L, input-text SHA-256, provenance,
ISO-8601 generation time, latency, cost/credit recording, raw metadata/audio
locations and audio SHA-256.

It also records the execution backend, platform, physical device/runtime,
OS version, TTS engine/package, voice identifier, network requirement,
audio-capture/generation method and whether a metered external service was
invoked.

For `native_os` evidence specifically:

- platform must be physical iOS or Android evidence;
- a real offline/network-disabled test is required;
- the result must be explicitly `pass` or `fail`;
- the benchmark sample must not invoke a metered external provider;
- recorded provider-usage cost must be zero when no metered service is invoked.

This does **not** mean total device or operational cost is zero. The evidence
only distinguishes metered external-provider usage from local/native execution.

The private canonical corpus text stays in Drive; the public repository stores
only generic validators/templates.

After all samples for the candidate set exist, validate cross-candidate
comparability:

```sh
python3 validate_voice_benchmark.py samples/*.json
```

Each candidate key must contain canonical corpus A-L exactly once, with unique
blind IDs and consistent corpus version plus runtime provenance: execution
backend, platform, device, OS, TTS engine/package, model/runtime version, voice,
locale, quality tier, network requirement and requested audio format.

For each A-L item, all candidates must also carry the same input-text SHA-256
and character count. This catches private-corpus mutation or non-comparable
benchmark sets without publishing corpus text or ranking candidates.

## Blind listening panel

Copy `LISTENING_PANEL_TEMPLATE.json`, add the actual blind sample IDs and native
or near-native Turkish listeners, then run:

```sh
python3 validate_listening_panel.py panel.json
```

The check enforces complete 1-5 ratings across the canonical dimensions, sample
order coverage, critical-defect recording and provider blinding. It deliberately
refuses automated winner/ranking semantics.

## Execution order

Where the required physical devices are available, collect zero-credential
native evidence first and reuse the R7-06 D1/D2/D3 device session where practical.
Then evaluate credible self-host/open candidates. Hosted/paid candidates remain
protected by the existing credential, terms/privacy/security and spend gates.

This order is an evidence-efficiency rule, not a preselected production winner.

## Important boundary

R7-07A still requires real audio, native/near-native Turkish human listening,
measured latency/cost and privacy/security/license review. R7-07B still requires
the parity-qualified Companion visual/state system and timing/failure coherence.
These tools only reduce evidence-packaging and comparability error.
