# ENGINEER RETURN — CLAUDE_HANDOFF_001 — V0 Architecture Spike

## Verdict

**GO_ADAPT (conditional)**. The mission LA-0009 → LA-0017 is complete and **AWAITING_BRAIN_REVIEW**.
Per-command return: [RET-0004](returns/RET-0004.md) (answers CMD-0002; supersedes checkpoint RET-0002).
[RET-0003](returns/RET-0003.md) answers CMD-0003 (D-029). The engineer does not self-declare PASS.

## 1. Execution identity and protected boundaries

| Field | Value |
| --- | --- |
| Repository | https://github.com/Jay-prodesign/sesli-ogren (PUBLIC) |
| Branch | `spike/v0-architecture-proof`, created from the reviewed bootstrap head `433c26cf5fa75a37b66b1f74dd6a133ae4d3407a` |
| Draft PR | [#2](https://github.com/Jay-prodesign/sesli-ogren/pull/2), stacked on `chore/repository-bootstrap`, draft, unmerged |
| Content head | `3dc6d1d1063f806784365754a96d0286594fd3e9` (the final reconciliation head is reported in PR #2) |
| `main` / PR #1 | `52616b4` untouched / draft, unmerged, untouched |
| Protected actions | None: no merge, deploy, release, LICENSE change, paid provider, credentials, secrets, or cross-project mutation |

## 2. LA-0009 control plane

CMD-0002 and CMD-0003 were transcribed from Drive (the Founder confirmed them as authoritative) and acknowledged in order.
TASKS: M0 is DONE and M1 is ACTIVE with LA-0009…LA-0017. D-029/D-028 are projected into AGENTS.md §14, CLAUDE.md,
`.claude/rules/engineering-quality.md` and the plan template; D-031 is projected into AGENTS §8. The bus now has PARTIAL
checkpoint returns. Validator and negative suite: green.

## 3. LA-0010 donor currentness and reuse ([detail](../architecture/spike/LA-0010-upstream-audit.md))

All six candidates are pinned at exact commits with licences read at those commits: MoonlighC MIT, Open Notebook MIT,
OpenTutor MIT, Nibomo MIT, NotebookLM-Lite Apache-2.0, vercel/ai Apache-2.0. Only `vercel/ai` drifted from Brain's pin.
MoonlighC suites were executed: migrations **35/35**, Flutter **633/633**, Deno **404/404**, SQL tests **10/26 at HEAD**
(24/26 at their authored step). Its SQL tests are step scripts, not a HEAD regression suite. No donor code was imported before classification.

## 4. LA-0011 canonical model ([detail](../architecture/spike/LA-0011-canonical-model-mapping.md))

All 15 canonical objects are mapped. There is one authority per concept:

- The donor `public.materials` mega-object is **split** into Material, SourceAsset, ExtractedContent and Artifact.
- The donor's two generation systems are **unified** into `generation_jobs/attempts`.
- The Summary is a versioned Artifact. `materials` has no summary column (test-enforced).
- There are no dual writes and no donor tables in the canonical schema.

## 5. LA-0012 provider seam ([detail](../architecture/spike/LA-0012-provider-seam.md))

`StructuredGenerationCapability` is Learning App-owned and has **no imports**. It ships with a deterministic fake, a
dependency-free fetch adapter, and a worker that records dispatch before calling the provider. The Vercel AI SDK works on
Deno, but it is 307.7 KB minified against 3.3 KB for the fetch adapter, pulls in 11 packages against 0 (including an
unused Gateway client), and releases 35 times in 30 days. It is therefore **not adopted**; the concrete reason and a
revisit trigger are logged. No live provider was called and no Gateway was used.

## 6. LA-0013 bounded end-to-end

The chain is proven in SQL, in a Deno worker against real Postgres, and in a separate session for reopening:

1. authenticated user;
2. Material;
3. SourceAsset;
4. ExtractedContent;
5. Job;
6. Attempt;
7. deterministic Summary;
8. persistent Artifact;
9. Library projection;
10. reopen from persistence.

The Flutter contract package decodes the **actual owner-visible DB rows** into canonical models. The proof-only status
card covers queued, processing, success, failure and retry. It is labelled as proof UI (D-028), not product design.

## 7. LA-0014 isolation

Covered by [detail](../architecture/spike/LA-0013-0015-flow-isolation-idempotency.md) and `20_tenant_isolation.sql`:

- anon is denied;
- a request with no subject is refused;
- user B sees 0 rows in every canonical table and in the library;
- direct writes are denied;
- cross-user RPCs return a **non-revealing** error;
- worker RPCs are denied to clients;
- storage paths grant nothing;
- clients cannot read or write lease tokens;
- deletion revokes all derived access.

No cross-user access was observed.

## 8. LA-0015 retry, idempotency and lineage

Covered by `30_job_idempotency.sql` and the Deno integration test:

- same key → same job; same request with a new key → same live job (fingerprint plus a unique partial index);
- key reuse on another material is rejected;
- after a retryable failure there is no auto re-dispatch, and a user retry creates a linked attempt;
- a stale lease or token cannot mutate the job;
- after a crash that follows dispatch the request is **never resent**; it is reconciled instead;
- after a crash before dispatch the job re-runs safely;
- each job has one artifact, one usage event and one quota consumption;
- regeneration is a separate intent;
- quota is enforced on the server.

## 9. LA-0016 burden and selector ([detail](../architecture/spike/LA-0016-layered-donor-decision.md))

Donor files copied verbatim: 0; one function (`set_updated_at`) was reused directly. Four donor migrations were adapted.
The migrations shrink from 35 to 2 and the SQL functions from 97 to 17. The canonical re-point touches **38/112** donor
Dart files, and there are **0** dual-write layers. The full D-025 capability matrix covers 17 rows.

**GO_ADAPT conditions:**
1. The canonical schema is the only authority.
2. The first unit re-points the donor client's material/summary path and removes `MockAiService` from it.
3. The PDF analysis pipeline is re-keyed onto the canonical job model as its own tranche.
4. The canonical SQL regression suite grows every tranche.

## 10. Tests and evidence (commands run)

| Suite | Result |
| --- | --- |
| `spike/architecture-proof/db/run_sql_suite.sh` (Postgres 16.13 + shim) | migrations 2/2, tests **4/4** (~90 assertions) |
| `deno lint` / `deno check` / `deno test -A` (Deno 2.9.7, `LA_TEST_DB` set) | clean / clean / **13/13** |
| `flutter analyze` / `flutter test` (Flutter 3.47.5) | clean / **5/5** |
| Mutation checks | **3/3** caught |
| `python3 scripts/validate_bootstrap.py` / negative suite | green / **41** OK |
| Rollback rehearsal (worktree at `433c26c`) | base validator + negatives green without the spike |
| Secret sweep (tokens, JWT, keys, private keys, secret files) | clean |
| CI `bootstrap-validation` | green on all heads except `521ec04` (fixed in `c894bd8`) |
| CI `spike-proof` (new, read-only) | re-runs the SQL and Deno proofs on PR #2; the final result is in the PR checks |

## 11. Provenance

- REUSE-0001: MoonlighC `set_updated_at`, DIRECT-REUSE.
- REUSE-0002: MoonlighC tenancy, storage and job mechanics, ADAPT.
- REUSE-0003: `flutter_lints` 6.0.0, dev DEPENDENCY.
- Rejected approved candidate: `vercel/ai` 7.0.118.
- The MIT notice is kept at `docs/provenance/licenses/`. No private Drive text was copied.

## 12. D-029 disposition

- **Where it was integrated:** AGENTS.md §14, CLAUDE.md, `.claude/rules/engineering-quality.md`, the plan template,
  a `Quality considerations (D-029)` section in every M1 plan, and validator checks.
- **Final Engineering Test:** recorded for the canonical split (LA-0011), SDK vs fetch (LA-0012), the idempotency
  design (LA-0013–15), and the selector (LA-0016).
- **Declared open item:** #4 for the selector. The client re-point is measured, not executed.
- **N/A:** LA-0009 (governance only) and LA-0014 (verification, no new design).

## 13. Known limitations and debt

1. A Supabase shim was used instead of the CLI/Docker stack, so the PostgREST, GoTrue and Storage HTTP layers are not exercised.
2. The donor client is not yet re-pointed to the canonical tables. The count of 38 Dart files is static measurement.
3. `lib/app/app_state.dart` is a 4,163-line god object and should be decomposed while re-pointing.
4. The donor PDF analysis pipeline (~20 SQL functions, 242 Deno tests) still needs re-keying onto canonical jobs.
5. The canonical SQL suite must grow with every tranche; the donor has no HEAD regression suite.
6. Failed-but-executed attempts record no UsageEvent. Attempt-level cost events are needed before real providers are used.
7. The fetch adapter classes pre-send transport errors as `ambiguous`. This is conservative.
8. Flutter client tests run locally only; CI has no Flutter toolchain step.
9. The donor migration `phase_c_role_portability` test fails at donor HEAD. This is a donor issue and is not inherited.

## 14. Rollback

Delete `spike/v0-architecture-proof` and close PR #2 unmerged (Product Owner / Brain decision). The schema is
greenfield, there is no production data, and `main` and PR #1 are untouched. The rehearsal shows the base remains green.

## 15. Next recommended implementation unit

**VS-001 foundation, per condition 2.** Import the MoonlighC Flutter shell under a new admitted task with REUSE entries,
apply the canonical migrations, and re-point the material → summary path (`StudyMaterial` / `materials.summary` →
`library_items` / `artifacts`, `MockAiService` → server generation). Keep donor tests green or replace them one-for-one.
The first Owner Preview follows D-032.

## 16. Unresolved owner / architecture decisions

- **Provider/model vendor and credentials (D-031, paid gate).** Needed before any live generation. Not needed for the proof.
- **Donor client import into this repository.** This is a D-024 reuse action within the next admitted task. Brain should
  confirm the admission.
- **Bridge activation (AUTO_AGENT_BRIDGE_BLOCKED)** remains an optional Founder gate.
