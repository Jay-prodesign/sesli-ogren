# M5 Supabase Auth Configuration

The production runtime requires a real Supabase Auth session before opening learner-scoped SQLite data.

## Authority

- Canonical identity direction: Supabase Auth + canonical IdentityAccount.
- The server schema maps `public.accounts.id` one-to-one to `auth.users.id`.
- The client therefore uses the authenticated Supabase user UUID as `LearnerId/account_id`.
- Test/proof code may inject `AppRuntime.localM5LearnerFixture`; production `SesliOgrenApp` may not.

## Client configuration

Provide only client-safe values at build/run time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<sb_publishable_...>
```

Do not commit a service-role/secret key or provider credential. The publishable key is intentionally a client credential; authorization remains enforced by Auth/RLS and server RPC boundaries.

## Authentication behavior

1. Initialize Supabase from `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY`.
2. Reuse the persisted current session when present.
3. With no session, show explicit passwordless account entry.
4. Request an email OTP with Supabase Auth; the same flow may create a new account when allowed by project policy.
5. Verify the six-digit OTP and open `AppRuntime` only after Supabase returns a real authenticated user/session.
6. Local sign-out removes only the device session; learner-scoped local data remains isolated under the authenticated user UUID.
7. Missing config or failed auth is fail-closed: learner data is not opened.

## Project-side prerequisite

Email OTP/passwordless sign-in must be enabled and deliverable for the selected Supabase project. Before release, verify the production email sender/template, delivery behavior, rate limits/anti-abuse posture, account recovery/linking expectations, and the exact allowed redirect/deep-link configuration if those flows are introduced.

Anonymous sign-in is not the current product entry flow.

## Checkpoint evidence

At a release checkpoint record:
- selected Supabase project identity (project ref only; no secret);
- email OTP enabled and one real delivery/verification round-trip completed;
- session restore and local sign-out behavior verified;
- no service-role/provider secret in repo/app config;
- RLS/grants remain fail-closed for cross-user access;
- account deletion still removes the server account/data boundary before local purge.

Live email delivery/template validation is external release evidence and must not be inferred from unit tests alone.
