#!/usr/bin/env python3
"""Cross-sample completeness checks for the R7-07A Turkish voice benchmark.

Each candidate key must cover the same canonical corpus A-L exactly once. This
preserves cross-provider comparability without ranking candidates.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

from validate_voice_sample import CORPUS_ITEMS, validate as validate_sample


def _load(path: str) -> dict[str, Any]:
    with Path(path).open("r", encoding="utf-8") as fh:
        value = json.load(fh)
    if not isinstance(value, dict):
        raise ValueError(f"{path}: top-level JSON must be an object")
    return value


def validate_benchmark(records: list[dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    seen_ids: set[str] = set()
    by_candidate: dict[str, list[dict[str, Any]]] = defaultdict(list)

    for index, record in enumerate(records):
        sample_errors = validate_sample(record)
        errors.extend(f"record[{index}]: {e}" for e in sample_errors)

        sid = record.get("blind_sample_id")
        if isinstance(sid, str):
            if sid in seen_ids:
                errors.append(f"duplicate blind_sample_id: {sid}")
            seen_ids.add(sid)

        candidate = record.get("hidden_provider_model_voice_key")
        if isinstance(candidate, str) and candidate.strip():
            by_candidate[candidate].append(record)

    if not records:
        errors.append("benchmark must contain at least one sample record")
        return errors

    if not by_candidate:
        errors.append("benchmark contains no valid candidate keys")
        return errors

    for candidate, samples in by_candidate.items():
        corpus = [s.get("input_corpus_item") for s in samples]
        if len(samples) != len(CORPUS_ITEMS):
            errors.append(
                f"candidate {candidate!r} must contain exactly {len(CORPUS_ITEMS)} samples (A-L); got {len(samples)}"
            )
        if set(corpus) != CORPUS_ITEMS or len(corpus) != len(set(corpus)):
            errors.append(f"candidate {candidate!r} must cover corpus A-L exactly once; got {corpus}")

        versions = {s.get("input_corpus_version") for s in samples}
        if len(versions) != 1:
            errors.append(f"candidate {candidate!r} must use one corpus version; got {sorted(map(str, versions))}")

        locales = {s.get("language_locale") for s in samples}
        if len(locales) != 1:
            errors.append(f"candidate {candidate!r} must use one consistent Turkish locale; got {sorted(map(str, locales))}")

        formats = {s.get("requested_format") for s in samples}
        if len(formats) != 1:
            errors.append(
                f"candidate {candidate!r} must use one consistent requested format for comparability; got {sorted(map(str, formats))}"
            )

        tiers = {s.get("synthesis_mode_or_quality_tier") for s in samples}
        if len(tiers) != 1:
            errors.append(
                f"candidate {candidate!r} must use one consistent synthesis mode/quality tier; got {sorted(map(str, tiers))}"
            )

    # Cross-candidate text identity: for every A-L item, all candidates must
    # use the same canonical input hash and character count without publishing
    # the private corpus text into the public repository.
    for item in sorted(CORPUS_ITEMS):
        rows = [r for r in records if r.get("input_corpus_item") == item]
        hashes = {r.get("input_text_sha256") for r in rows}
        counts = {r.get("input_character_count") for r in rows}
        versions = {r.get("input_corpus_version") for r in rows}
        if len(hashes) != 1:
            errors.append(f"corpus item {item} must use one identical input_text_sha256 across candidates")
        if len(counts) != 1:
            errors.append(f"corpus item {item} must use one identical input_character_count across candidates")
        if len(versions) != 1:
            errors.append(f"corpus item {item} must use one identical input_corpus_version across candidates")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("records", nargs="+", help="Completed R7-07A sample JSON files")
    args = parser.parse_args()

    try:
        records = [_load(path) for path in args.records]
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}")
        return 2

    errors = validate_benchmark(records)
    if errors:
        print(f"FAIL: {len(errors)} voice-benchmark checks failed")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        f"PASS: {len(by := {r['hidden_provider_model_voice_key'] for r in records})} candidate(s) "
        "each cover canonical corpus A-L exactly once"
    )
    print("NOTE: comparability completeness is not ranking, provider selection, or R7-07 PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
