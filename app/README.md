# Uncpanion

Flutter companion app for the NEXUS 2026 ESP32 wearable. This first increment implements the app interface and an independent app-local focus timer. The watch firmware now advertises a read-only BLE telemetry service.

## Run

Install the stable Flutter SDK using https://docs.flutter.dev/install/manual, then from this folder:

```sh
flutter pub get
flutter run -d web-server --web-port 8081
```

The web target is a local preview of the Flutter app. Android and iOS are the intended phone targets. Native builds need the Android SDK or Xcode and device signing, respectively.

```sh
flutter analyze
flutter test
flutter build web
```

## Netlify deployment

Run `flutter build web`, then upload the contents of `build/web` using Netlify's manual deploy interface. The app uses a single root URL and keeps tab navigation in memory, so refreshing the deployed site does not require rewrite rules. No `netlify.toml`, backend, environment variables, or build plugin is required.

The public build starts with Demo Mode enabled. Health and Activity remain interactive without Bluetooth, including in browsers that do not expose Web Bluetooth. A real watch can still be connected from Device in a compatible browser; live BLE data takes precedence while connected.

## Implemented

- Home: animated/blinking Unc, tap-to-talk encouragement, focus summary.
- Focus: 1–8 sessions, real 25/5/15-minute durations, pause/resume, phase catch-up after suspension, completion records for the current app run.
- Health: explicitly labeled Demo Mode optical pulse and day/week charts; toggle example data off to inspect the empty state.
- Activity: example movement patterns and rotating break suggestions.
- Device: explicit Demo/Live mode selection plus real service-filtered discovery, connection, notifications, disconnect, retry, and unsupported-browser handling.
- Connected Health/Activity: real BPM, optical pulse, and movement status. Watch focus status is shown separately from the app timer.
- Responsive scrolling layouts, navigation labels, button tooltips, reduced-motion awareness, and a centered 430-pixel phone-style desktop shell.

## Boundaries

Read-only BLE streaming is implemented. No remote watch control or historical synchronization yet. No stress/sleep/temperature/step estimates or wellness score. No backend, account, cloud upload, AI, or medical interpretation. Disconnected initial sensor charts are labeled examples; connected views use real telemetry and clear stale readings; app focus records are in memory and clear on reload or process termination. No background notifications. The timer catches up when the app resumes, but cannot notify while the app is suspended.

## Structure

- `lib/main.dart`: app shell, screens, visual components.
- `lib/app_state.dart`: app-local focus state, injected clock for deterministic tests.
- `lib/demo_data.dart`: isolated illustrative chart values.
- `test/`: timer transitions, pause/resume, navigation, device disclosure, compact layouts.
- `docs/ble-next.md`: implemented protocol, setup, limitations, and physical checks.

## Manual acceptance

1. Tap Unc: dialogue changes without navigating away.
2. Start Focus, switch tabs, return, pause and resume.
3. Toggle Health example data; compare Day and Week views.
4. Try another Activity break idea.
5. Find the watch in Device and connect. Check real Health/Activity and watch focus status. Disconnect and verify values clear.
6. Inspect at phone width and enlarged text.

Built with AI development assistance and Flutter's open-source framework. Team members should review and understand the implementation and disclose assistance in their competition materials as required by their guidebook.

## This Mac

A temporary SDK was installed at `/private/tmp/nexus-flutter-sdk` (Flutter 3.47.3 / Dart 3.13.3). `./tool/run-preview.sh` uses Flutter from PATH or this temporary SDK. The temporary folder may be cleaned by macOS; install the SDK permanently before relying on it long-term.

Android SDK and full Xcode were not found during setup. Native builds have not been validated. Flutter also flagged the existing Java installation as incompatible with the generated Gradle version; Android setup will need a compatible JDK (17–25). No system Java settings were changed.

## BLE validation

Firmware compiled and uploaded with ESP32 core 3.3.3. Flutter analysis and ten tests pass, including packet validation, expiry, disconnect, failed connection, and unsupported-browser behavior. Live hardware connection verification is reported separately in the task. Native Android/iOS builds remain unverified.

The current production preview is served at http://127.0.0.1:8083/. The in-app browser previously connected and displayed live watch focus, changing acceleration, inactivity, and no-finger heart-rate status. The reconnect flow was subsequently fixed and physically verified.
