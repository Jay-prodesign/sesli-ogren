# Supabase Auth Configuration

The production Learning App runtime requires a real Supabase Auth session before learner-scoped SQLite data is opened.

## Authority

- Canonical product direction uses Supabase Auth + the canonical IdentityAccount boundary.
- The accepted server schema maps `public.accounts.id` one-to-one to `auth.users.id`.
- The Flutter client therefore uses the authenticated Supabase user UUID as `LearnerId/account_id`.
- Test/proof code may inject `AppRuntime.localM5LearnerFixture`; production `SesliOgrenApp` may not.

## Client configuration

Provide only client-safe values at build/run time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<sb_publishable_...>
```

Do not put a service-role key, Supabase secret key, AI-provider key, or worker secret in the Flutter application. The publishable key is a client credential; authorization remains enforced by Auth, RLS, and server-side RPC/function boundaries.

## Production authentication behavior

1. Initialize Supabase from `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY`.
2. Reuse the locally persisted authenticated session when one exists.
3. If no session exists, show the account-entry flow.
4. The learner enters an email address and requests a one-time email code.
5. Verify the six-digit email OTP with Supabase Auth.
6. Open `AppRuntime` only after Supabase returns a real authenticated user UUID and session.
7. Missing client config, failed OTP delivery, failed verification, or an invalid session fails closed: learner data is not opened.
8. Signing out clears only the local auth session; account deletion is a separate explicit server-confirmed flow.

Anonymous sign-in is not the current production auth path. Older M5 anonymous-auth notes are historical proof context and must not be used to configure the current app.

## Project-side prerequisites

Before an auth acceptance run:

- Email authentication / email OTP must be enabled for the selected Supabase project.
- The configured email delivery path must be able to deliver the OTP to the test address.
- The client build must receive only the project URL and publishable key.
- RLS and authenticated RPC grants must remain fail-closed across users.
- Account creation by OTP remains enabled only when the intended current product policy allows a new learner account.

Before public release, separately verify email deliverability, rate limiting / abuse controls, account recovery and linking policy, privacy disclosures, and platform-specific authentication requirements.

## Server AI configuration

AI credentials remain server-side. The Flutter client must never receive them.

The current server functions expect their approved server environment configuration (for example `LEARNING_AI_API_KEY`, `LEARNING_AI_MODEL`, and `LEARNING_AI_BASE_URL`). A deployed Edge Function does not prove those provider settings are present or valid; run an authenticated bounded acceptance request before claiming live AI generation.

## Acceptance evidence

For the current runtime checkpoint record only non-secret evidence:

- selected Supabase project ref;
- one successful email OTP delivery + verification;
- authenticated session/user UUID exists;
- session restore works after app reopen;
- sign-out returns to account entry without deleting learner data;
- no service-role/secret/provider credential is present in the app or repository;
- cross-user RLS/grants remain fail-closed;
- server-backed AI actions fail honestly when provider configuration is absent.

Physical iOS/Android auth and email deep-link/keyboard/accessibility behavior remain part of the protected native-device release gate.
