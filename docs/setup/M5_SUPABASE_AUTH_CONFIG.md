# M5 Supabase Auth Configuration

M5 production runtime requires a real Supabase Auth session before opening learner-scoped SQLite data.

## Authority

- Canonical V0 direction: Supabase Auth + canonical IdentityAccount.
- Accepted M4 schema maps `public.accounts.id` one-to-one to `auth.users.id`.
- The M5 client therefore uses the authenticated Supabase user UUID as `LearnerId/account_id`.
- Test/proof code may inject `AppRuntime.localM5LearnerFixture`; production `SesliOgrenApp` may not.

## Client configuration

Provide only client-safe values at build/run time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<sb_publishable_...>
```

Do not commit a service-role/secret key. The publishable key is intentionally a client credential; authorization must remain enforced by Auth/RLS.

## M5 authentication behavior

1. Initialize Supabase from `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY`.
2. Reuse the persisted current session when present.
3. Otherwise call Supabase anonymous sign-in to create a real authenticated user/session without introducing login UX breadth.
4. Open `AppRuntime` only after an authenticated user UUID exists.
5. Missing config or failed auth is fail-closed: learner data is not opened.

## Project-side prerequisite

Anonymous sign-ins must be explicitly enabled for the selected Supabase project. Before public release, anonymous-auth anti-abuse/CAPTCHA and account-linking/recovery posture must be separately reviewed; M5 uses anonymous auth only to prove the admitted authenticated single-learner slice without expanding account UX.

## Checkpoint evidence

At M5 checkpoint record:
- selected Supabase project identity (project ref only; no secret);
- anonymous sign-in enabled;
- one successful authenticated session/user ID;
- no service-role/secret key in repo/app config;
- if server tables are exercised, RLS/grants remain fail-closed for cross-user access.
