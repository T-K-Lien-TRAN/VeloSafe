# VéloSafe GPS update

The map now requests location on opening, subscribes to live positions (5 m distance filter), updates the blue user marker and recenters after map style initialization. Press the GPS button to re-enable follow mode.

## Run

1. Copy `.env.example` to `.env` if needed, and provide your existing **public/publishable** API keys. The ZIP intentionally excludes `.env` and other local secrets. Never put a Supabase service-role key in a client app.
2. Run `flutter pub get` then `flutter run -d chrome` from the `VeloSafe` directory.
3. In Chrome allow location for the local site; turn on operating-system location services. Chrome on a laptop may determine location from Wi-Fi/IP and cannot guarantee GPS precision. Test Android on a real phone for better GPS results.
4. The status shows estimated position accuracy (metres). If GPS is denied/unavailable, Nice remains visible **only as a labeled sample**, not as a claimed actual location. The GPS button retries/recenters.

Continuous location updates occur while the app is active and permitted. Android/iOS background tracking is not implemented. A high-accuracy request does not guarantee precision. Safety score is recalculated around the latest reported position; hazards and backend data are otherwise unchanged.

## Validation

On a system with Flutter SDK installed, run `flutter pub get`, `flutter analyze` and `flutter run -d chrome` and verify permission prompts, map recentering, device movement and browser console GPS diagnostics. This environment did not have the Flutter/Dart toolchains installed, so compilation and live GPS testing have **not** been performed here.

## Diagnosing an incorrect position (October 2026)

The map now displays the **actual coordinates provided by the device/browser**, estimated accuracy, fix timestamp and mock status. Copy these coordinates into a maps website to verify them independently. If coordinates are incorrect, Flutter cannot manufacture the correct GPS reading. An Ubuntu laptop running Chrome commonly has no GPS chip; check OS location services, browser site permission and Wi-Fi geolocation, or run on a GPS-equipped Android phone. The accuracy radius is an estimate, not a guarantee.

Press the GPS button to request a **fresh** high-accuracy fix (instead of simply following the previously saved coordinates). Streaming updates continue while foregrounded. A location less accurate than 100 m is explicitly labeled approximate; changing this warning does not improve hardware accuracy.

In Chrome DevTools > More tools > Sensors, verify that Location is not being overridden to a fake location. On localhost, browsers generally allow geolocation; on deployed sites HTTPS is needed.
