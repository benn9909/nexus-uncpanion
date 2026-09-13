# NEXUS / Uncpanion

NEXUS is a hardware-first student productivity and wellness wearable built around an ESP32, a 128×64 monochrome OLED, an MPU6050 motion sensor, and a MAX3010x optical heart-rate sensor. Its companion Flutter app, **Uncpanion**, provides a larger view of live watch data and an app-local focus timer.

## Live demo

[Open the Uncpanion web demo](https://jovial-crostata-94d87f.netlify.app/). Demo Mode works without the watch or Web Bluetooth. Connecting the physical watch requires a Bluetooth-capable Chromium browser.

## Current status

- ESP32 firmware compiles and has been uploaded to the connected watch.
- The watch advertises a read-only BLE telemetry service named **Uncpanion Watch**.
- The Flutter web preview has connected to the physical watch and displayed live sensor data.
- Flutter automated checks: **10 passing**.
- The phone-native Android and iOS builds have not yet been validated.

## Features

### Watch

- OLED Home screen with Unc, changing mood, blinking, dialogue, and encouragement.
- Pomodoro-style Focus flow with session setup, focus, short break, long break, and pause/resume controls.
- Heart-rate screen with finger detection, BPM filtering, pulse heartbeat animation, and an adaptive optical waveform.
- Activity screen with a polished fixed layout instead of diagnostic sensor values:
  - `RESTING` with a stable sitting timer and inactivity progress bar
  - `MOVE NOW` reminder after inactivity
  - `MOVING` with a two-minute movement-break progress bar
  - `NICE WORK!` completion state
- Non-blocking motion, screen, animation, BLE, button, and Pomodoro updates driven by `millis()`.
- Left, centre, and right physical button navigation.

### Companion app

- Home, Focus, Health, Activity, and Device tabs.
- App-local Focus timer with 1–8 sessions, real 25/5/15-minute timings, pause/resume, and session history for the current app run.
- Live BLE discovery, connection, notification streaming, retry, disconnect, and stale-reading clearing.
- Connected Health view: live BPM, optical pulse waveform, and sensor/finger state.
- Connected Activity view: live movement state and acceleration-derived status.
- Device screen identifies the connection as read-only: the app does not control the watch.
- Example charts and activity content are clearly labeled while disconnected.

## Hardware and telemetry

| Part | Purpose |
|---|---|
| ESP32 | Watch controller and BLE peripheral |
| SSD1306 OLED (128×64) | Wearable interface |
| MPU6050 | Motion and inactivity detection |
| MAX3010x | Optical pulse and heart-rate sampling |

BLE uses service UUID `b7d10001-6a2b-4c3d-8e9f-102030405060` and telemetry characteristic UUID `b7d10002-6a2b-4c3d-8e9f-102030405060`. Notifications carry a compact 20-byte snapshot of sensor readiness, BPM, finger state, movement state, Pomodoro state, Unc mood, time remaining, acceleration, optical IR, and sequence number.

## Firmware layout

Open [Current_NEXUS_Progress.ino](Current_NEXUS_Progress/Current_NEXUS_Progress.ino) in Arduino IDE. It deliberately contains only hardware startup and the main loop.

| File | Responsibility |
|---|---|
| `Current_NEXUS_Progress.ino` | Hardware initialization and top-level loop |
| `nexus_core.cpp` | BLE, heart-rate processing, Pomodoro, buttons, navigation, Home, Focus, Health, and Unc behavior |
| `activity.cpp` | MPU activity detection and Activity state machine/UI |
| `display_helpers.cpp` | Centered text, headers, Unc faces, progress bars, and duration formatting |
| matching `.h` files | Shared interfaces and declarations |

The current demo inactivity threshold is **20 seconds**. Change the `inactivityThreshold` constant in `activity.cpp` for a production value.

## Build and upload watch firmware

Arduino IDE can open the sketch folder directly. The current board target is `esp32:esp32:esp32` on `/dev/cu.usbserial-10`.

```sh
arduino-cli compile --fqbn esp32:esp32:esp32 Current_NEXUS_Progress
arduino-cli upload --fqbn esp32:esp32:esp32 --port /dev/cu.usbserial-10 Current_NEXUS_Progress
```

The latest compiled size was about **1.14 MB / 87%** of available program storage and **12%** RAM.

## Run the app

From [app](app):

```sh
flutter pub get
flutter test
flutter run -d web-server --web-port 8083
```

For a public zero-config Netlify deployment, run `flutter build web` and manually upload the generated `app/build/web` folder. The app has no URL routes that require redirect configuration, so no `netlify.toml` is needed.

For web pairing, use a Bluetooth-capable Chromium browser, press **Find my watch**, then choose **Uncpanion Watch** in the browser chooser. USB supplies watch power; the app connects over Bluetooth.

## Competition compliance and dependencies

This repository is the source-code record required for N-HSIC 2026. See [DISCLOSURES.md](DISCLOSURES.md) for the required declaration of AI assistance and the open-source frameworks and libraries used by the prototype. The team should keep commits attributable to the people who performed the work and review every submitted component closely enough to explain it during judging.

Before the Round 2 deadline, the team must also submit the organizer's official Product Originality Declaration and disclose AI, open-source code/libraries, and mentor support in the product introduction video or listed technology stack. Those official submission materials are separate from this repository.

## Current boundaries

- BLE is read-only; remote watch control and historical synchronization are not implemented.
- No account, backend, cloud upload, AI feature, or medical interpretation is included.
- The app focus timer is independent of the watch focus timer.
- The watch activity target measures detected movement time; it is not a medical activity measure or step counter.
- Android/iOS packaging, signing, and physical native-device testing remain future work.

## Supporting notes

- [app/docs/ble-next.md](app/docs/ble-next.md) documents the BLE implementation and next validation steps.
- [Current_NEXUS_Progress/WORKLOG.md](Current_NEXUS_Progress/WORKLOG.md) records the Activity redesign and refactor history.
