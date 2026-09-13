# Development disclosures

This file records outside tools and reusable software used to develop **NEXUS / Uncpanion**. It supports the N-HSIC 2026 originality and ethics requirements. The team remains responsible for the submitted product and should be able to explain, test, and modify its implementation.

## AI assistance

OpenAI ChatGPT and Codex were used as development assistants for:

- planning and reviewing the watch and companion-app architecture;
- drafting and refactoring portions of the ESP32 firmware and Flutter source;
- debugging BLE connection behavior;
- improving UI layout, animation, and responsiveness;
- preparing documentation and running build, analysis, and test commands.

AI assistance must also be disclosed in the Round 2 product introduction video or listed technology stack and in the official Product Originality Declaration. Team members should review the final submission and be prepared to explain all code and design choices to judges.

## Open-source frameworks and libraries

### ESP32 firmware

| Component | Use |
|---|---|
| Arduino framework for ESP32 | Microcontroller runtime, GPIO, timing, I2C, and BLE support |
| Adafruit GFX Library | OLED drawing primitives and text rendering |
| Adafruit SSD1306 | SSD1306 OLED display driver |
| Adafruit MPU6050 | Motion-sensor driver |
| Adafruit Unified Sensor | Common sensor types used by the MPU6050 library |
| SparkFun MAX3010x Sensor Library | MAX3010x optical heart-rate sensor driver and beat detection |

### Flutter companion app

| Component | Use |
|---|---|
| Flutter | Cross-platform user interface and application framework |
| `universal_ble` 2.3.x | Bluetooth Low Energy discovery, connection, and notifications |

Exact resolved Flutter/Dart package versions are recorded in `app/pubspec.lock`. ESP32 library versions are managed by the Arduino installation used to compile the firmware and should be recorded in the final technical report or build environment before submission.

## Original work and third-party material

The project source in this repository is the team's NEXUS competition prototype. No competition PDFs, confidential organizer material, credentials, generated build output, or local IDE configuration are stored in the repository. Any future copied or adapted code, circuit design, 3D model, image, font, audio, or other third-party asset must be added to this file with its source and license before submission.

