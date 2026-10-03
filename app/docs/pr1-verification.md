# PR #1 fixes and team verification

Saved 4 October 2026 on `codex/pr1-reminder-fixes`, based on PR head `06a2cb5bc3ad9c0cc04444014cc76570fdfdf004`.

## Prepared changes

- Overload warnings count unfinished reminders due from now through the next 72 hours, using exact timestamps.
- Adding tasks prompts only when the count crosses from below five to five or more, not for every extra task.
- Focus help describes the actual 25-minute focus, 5-minute short break and 15-minute final break. Removed unused stress-adaptation methods and hardcoded sensor placeholders.
- Breathing text and expressions update at animation direction changes, including reversals between countdown updates.
- Regression tests cover reminder thresholds, deadline boundaries, completed tasks, repeated prompts and breathing cues.

The Add Task (Test) button remains a simulation with generated titles and deadlines two days ahead. Editable reminders and persistence are outside these fixes. Firmware and BLE code are unchanged.

## Verification status

**4 October 2026:** all 18 Flutter tests pass; `flutter analyze` reports no issues. Coverage includes reminder completion/deadlines, threshold-crossing prompts, breathing reversals, early dismissal, narrow dialogs with enlarged text, shared Demo Mode without Web Bluetooth, live-data precedence and return to demo after a mocked disconnect. No ESP upload or live sensor test was performed.

On 4 October 2026, `flutter build web` succeeded with Flutter 3.47.6 for the requested Netlify update. It emitted a non-fatal CupertinoIcons font warning. A successful build does not confirm the deferred tests or hardware behavior.

Published to https://nexus-uncpanion.netlify.app/ using the existing site's manual deploy flow. Netlify deployment: `6ac13ad69615910cb41b3aa9`. The public index loaded successfully, and the public `main.dart.js` SHA-256 matched the local build: `beea6697f6c0e52719f65973928b22feca7c992a96f4fc35597ab8869b09ac4b`. Source revision: `8f8f2ae`. This deployment did not merge or push the GitHub PR.

## Automated checks

From the repository's `app` directory, with Flutter on PATH:

```sh
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
flutter pub get
flutter test
flutter analyze
flutter build web
```

These checks do not require an ESP32. Run them before the hardware walkthrough.

On this Mac, Flutter is installed at `~/development/flutter`; the preview script also checks this location. The download was checked against the official archive's SHA-256 checksum. The SDK includes Dart; Android Studio and Xcode are not needed for these web checks.

The PATH command also prioritizes macOS's native Git because this Mac has an incompatible Intel Git at `/usr/local/bin/git`. The preview script falls back to native Git if the default Git cannot run. No global Git installation was changed.

## Team walkthrough

1. Add four tasks and mark them complete. Add a fifth: no overload alert should appear.
2. Reach five unfinished tasks. Dismiss the alert, then add another task: no repeat alert should appear.
3. Drop below five unfinished tasks and add a task to cross the threshold again. Choose Breathe with Unc. Check inhale accompanies growth and exhale accompanies shrinking, switching every 2.5 seconds. Check completion at ten seconds and closing early.
4. Read the Focus help. Start, pause, resume and reset the standard app timer.
5. Check Home and the breathing dialog at phone width and enlarged text. Narrow-screen and enlarged-text widget checks pass; desktop browser spot-checks were also performed.
6. With the ESP32 present, connect from Device. Check live heart rate, motion and watch focus telemetry, then disconnect/reconnect and check Demo Mode.

ESP/BLE checks still require the physical watch. The PR is left unmerged for team review.
