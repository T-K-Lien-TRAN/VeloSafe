# VéloSafe — Supabase-connected Flutter app

## Start with your .env (Ubuntu)

The repository includes platform folders. Open a terminal in this project:

```bash
flutter pub get
python3 scripts/run.py -d chrome
```

Copy your existing `.env` into the project root first. It must contain
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. The launcher passes only selected
client configuration through a private temporary JSON file; it does not execute
`.env` as shell code or bundle the `.env` file as an asset. It accepts a publishable
key or legacy anon key and rejects Supabase secret/service-role keys.

**First configure the database:** follow [SUPABASE_SETUP.md](SUPABASE_SETUP.md).
Your project was reachable during this update, but the API returned PGRST205
for `public.hazards`: the hazards table was not available in the API schema cache.
A publishable key cannot run SQL migrations.

For a phone, use `flutter devices`, then:

```bash
python3 scripts/run.py -d YOUR_DEVICE_ID
```

For real bicycle routes during local development only:

```bash
python3 scripts/run.py --local-routes -d chrome
```

This option embeds your ORS key in the test build. For public deployment,
use a backend and set `ROUTING_API_URL` instead.

## What changed

- Real mode requires Supabase configuration and checks table access at startup.
- Sample data is opt-in: `flutter run -d chrome --dart-define=DEMO_MODE=true`.
- Reports are saved with database-generated UUIDs, owner IDs and timestamps.
- Insert and resolve return the saved database row immediately.
- Confirmation reloads the database count after the transaction.
- Realtime updates other clients; a 30-second refresh also recovers missed events.
- Repeatable SQL enables Realtime and restricts database writes through RLS and
  column grants. Only the owner resolves; each account confirms at most once.

Anonymous Supabase sign-in creates a persisted session on that installation/browser.
It does not provide an email/password login or cross-device account recovery.
Clearing app/browser data can lose access to the reporter's identity.

## Verification

```bash
python3 -m unittest discover -s scripts -p 'test_*.py'
flutter analyze
flutter test
```

The launcher tests do not need Flutter. Flutter/Dart are required for the other checks.
See the setup guide for a two-device database acceptance test.

