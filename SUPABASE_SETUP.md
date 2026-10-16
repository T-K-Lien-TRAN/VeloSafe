# Connect the real database

1. Open your existing project at https://supabase.com/dashboard.
2. Open SQL Editor, create a query, paste all of `sql/001_hazards.sql`, and Run.
   Run this version even if you ran the original earlier. It is transactional
   and can be repeated for this app's expected schema. It does not seed fictional
   reports. If an existing table has a different schema, resolve the SQL error
   rather than deleting user data.
3. In Authentication settings, enable Anonymous Sign-ins. No service-role key
   belongs in the Flutter app. The launcher uses your publishable/anon key.
4. Put your existing `.env` next to `pubspec.yaml`. Do not add `.env` to Git.
5. Run `flutter pub get`, then `python3 scripts/run.py -d chrome`.

The migration creates `hazards` and `hazard_confirmations`, the confirmation RPC,
RLS policies, explicit privileges, indexes, and Realtime publication membership.
Database defaults set `created_at`, `id` and `reporter_id`; clients cannot override
those columns. Confirmation does not restart the report date. Only the reporter
can change an active report to resolved. Resolved reports are excluded by the
existing Safety Score calculation.

## Verify real storage with two sessions

Use Chrome plus an Android phone, or two independent browser profiles:

1. Open session A and create a clearly identifiable test report using a map pin
   or real GPS. Record the displayed coordinates.
2. In Supabase Table Editor, confirm the row exists in `hazards`, has those
   coordinates, a database timestamp, and a non-empty `reporter_id`.
3. Reload A: the report must remain and A must still be able to resolve it.
4. Open B: the report should appear. Realtime normally propagates changes;
   periodic refresh provides a fallback within about 30 seconds.
5. In B, press Still there twice. The count must increase once, and the database
   must contain only one `(hazard_id, user_id)` pair for B.
6. B must have no enabled Resolved button for A's report. A can resolve it;
   verify the status changes and it stops contributing to the Safety Score.

No live test reports were inserted during preparation of this update.

## Troubleshooting

- **PGRST205 / table not found:** run the migration in the same project whose
  URL is in `.env`. If the table exists but is not exposed yet, reload the API
  schema cache: `notify pgrst, 'reload schema';` in SQL Editor.
- **Anonymous sign-ins disabled:** enable the provider and restart the app.
- **Permission / RLS errors:** rerun the migration; verify that a session exists
  in Authentication > Users. Do not bypass RLS with a service-role key.
- **Empty map of hazards:** a new database contains zero reports; create one.
- **GPS denied:** grant location permission or place a pin manually. Map centering
  in Nice when GPS fails is a labeled fallback, not your detected location.
- **Other session is delayed:** check the Realtime publication and network.
- **Routes are a preview:** use `--local-routes` for a local test, or configure
  a deployed routing proxy. Supabase stores reports; it does not calculate routes.

## Limits

This update connects the reporting MVP to a real database. It does not implement
moderation, robust anti-spam, email accounts, or turn-by-turn navigation. The
report-based Safety Score remains experimental. The app currently loads the
hazards table for all users; add geographic queries and pagination before scaling
up to a large dataset. Anonymous accounts identify sessions rather than people.

Official references:
- https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- https://supabase.com/docs/guides/auth/auth-anonymous
- https://supabase.com/docs/guides/database/postgres/row-level-security
