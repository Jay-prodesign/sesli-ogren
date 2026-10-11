# V0 Email OTP Auth Configuration

LA-0036 uses passwordless email OTP for new-session account entry.

## Client contract
The Flutter app needs only:
- SUPABASE_URL
- SUPABASE_PUBLISHABLE_KEY

Never place a Supabase secret/service-role key in Flutter, repository source, or client build configuration.

## Hosted Supabase configuration required before live acceptance
1. Keep Email authentication enabled.
2. Configure the email authentication template to deliver a 6-digit OTP by including the Supabase `{{ .Token }}` variable instead of relying only on a Magic Link.
3. Verify the OTP expiration/rate-limit policy is acceptable for launch.
4. Before public commercial launch, use production-grade transactional email/SMTP appropriate to the target volume and validate deliverability.
5. Run a real-device account-entry check: request code → receive email → verify code → close/reopen → same Auth user restored.

## Current execution boundary
- Repository/client implementation may be validated without production credentials.
- Hosted auth configuration, live email delivery, SMTP selection, and public-release acceptance are external release-gate work.
- LA-0036 does not deploy database migrations or Edge Functions and does not change the currently empty hosted product schema.
