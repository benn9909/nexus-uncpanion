# Uncpanion BLE protocol v1

Firmware advertises `Uncpanion Watch` with service `b7d10001-6a2b-4c3d-8e9f-102030405060`. Read/notify characteristic: `b7d10002-6a2b-4c3d-8e9f-102030405060`.

The snapshot is exactly 20 bytes, fitting the default ATT payload without MTU negotiation. Unsigned multibyte integers are little-endian. Firmware refreshes it at most every 100 ms; actual cadence depends on the existing cooperative sensor/button loop. Advertising resumes after a disconnect.

| Byte | Meaning |
| --- | --- |
| 0 | Version: 1 |
| 1 | Flags: bit 0 MAX sensor OK, 1 IMU OK, 2 finger present, 3 stabilized, 4 valid recent BPM, 5 Pomodoro running |
| 2 | Rounded median BPM, or 255 when unavailable |
| 3 | Movement: 0 still, 1 moving, 2 inactive, 255 unavailable |
| 4 | Pomodoro: 0 setup, 1 focus, 2 short break, 3 long break |
| 5 | Current session (1–8) |
| 6 | Selected sessions (1–8) |
| 7 | Unc: 0 happy, 1 focused, 2 resting, 3 active, 4 inactive |
| 8–11 | Actual remaining milliseconds, including the existing compressed test durations |
| 12–13 | Acceleration magnitude × 100, or 65535 unavailable |
| 14–17 | Latest raw IR with finger present, else 0 |
| 18–19 | Snapshot sequence, wrapping at 65535 |

The app validates packets, removes duplicate sequence values, and hides data after 3 seconds without a fresh valid packet. Finger removal clears BPM and pulse history. Disconnect clears all live readings. Pulse graph filtering is display-only and does not modify firmware BPM detection.

The app's focus timer remains independent. The watch is authoritative for the separate WATCH FOCUS panel and live Unc face. No BLE writes, remote controls, permanent history, or recovery of missed readings are implemented.

## Connect

1. Power the ESP32 with the BLE firmware.
2. Open Device → Find my watch.
3. Allow Bluetooth access when prompted and choose Uncpanion Watch.
4. Select the discovered watch in the app. Status changes after service discovery and subscription.
5. Health and Activity switch from examples to real data. To reconnect, use the same flow.

Browser preview requires Web Bluetooth support and a secure context (localhost qualifies). The app checks whether the API exists and explains when it is unavailable. Embedded browsers and Safari may not support this flow. A supported Chrome/Edge browser on the Mac can use the local preview; USB connection alone is not app connectivity. The browser and operating system control the device chooser and permissions.

Android manifests include Bluetooth scan/connect and legacy location permissions (only for older Android). iOS includes Bluetooth purpose strings. Native builds still require Android SDK/JDK or Xcode/signing and have not been validated on a phone.

This MVP uses unencrypted, read-only GATT telemetry; do not treat it as secure storage or a production private health-data transport. The BLE advertisement contains the service/name, not heart-rate readings. No data is uploaded to a server.

Library: Universal BLE 2.3.0, BSD-3-Clause. Documentation: https://pub.dev/packages/universal_ble . Firmware uses the BLE library bundled with Espressif Arduino core 3.3.3.

## Physical checks

- Place/remove finger: live BPM becomes available/unavailable appropriately.
- Move/hold the watch still: real movement states change.
- Start/pause Pomodoro on the watch: WATCH FOCUS reflects it; app timer stays independent.
- Disconnect/reconnect: stale readings clear; the watch advertises again.
- Hold a button: the existing blocking button code may pause telemetry; the app must show unavailable rather than retain a stale measurement.

## Verified on this Mac

The in-app browser connected to the ESP32 and received real focus status, changing acceleration, inactivity, and the no-finger health state. A live BPM with a finger was not observed during this check. Disconnect cleared data. Reconnecting through a previously saved device entry failed; the controller now waits for disconnect cleanup and removes old discovery entries. Ten automated tests pass, including the cleanup race. Physical retesting of the revised reconnect flow is pending a fresh chooser selection.
