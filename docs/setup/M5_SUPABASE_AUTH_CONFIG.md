# M5 Supabase Auth Configuration

The production runtime requires a real Supabase Auth session before opening learner-scoped SQLite data.

## Authority

- Canonical identity direction: Supabase Auth + canonical IdentityAccount.
- The server schema maps `public.accounts.id` one-to-one to `auth.users.id`.
- The client therefore uses the authenticated Supabase user UUID as `LearnerId/account_id`.
- Test/proof code may inject `AppRuntime.localM5LearnerFixture`; production `SesliOgrenApp` may not.

## Client configuration

The production client carries the selected Sesli Öğren Supabase project URL and its modern `sb_publishable_...`
key as client-safe defaults. Supabase explicitly treats publishable keys as public client credentials suitable for
mobile apps and public source; they do not bypass RLS.

Use Dart defines only when intentionally targeting another environment:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<alternate-project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<alternate-sb_publishable_...>
```

Never commit or embed a Supabase secret/service-role key or an AI-provider credential. Authorization remains
enforced by the authenticated user's JWT plus RLS and server RPC ownership checks.

## Authentication behavior

1. Initialize Supabase from the production client-safe defaults, or explicit `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` overrides.
2. Reuse the persisted current session when present.
3. With no session, show explicit passwordless account entry.
4. Request an email OTP with Supabase Auth; the same flow may create a new account when allowed by project policy.
5. Verify the six-digit OTP and open `AppRuntime` only after Supabase returns a real authenticated user/session.
6. Local sign-out removes only the device session; learner-scoped local data remains isolated under the authenticated user UUID.
7. Failed initialization or failed auth is fail-closed: learner data is not opened.

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
