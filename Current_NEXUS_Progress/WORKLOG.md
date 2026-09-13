# NEXUS watch continuation note

The watch firmware was being refactored from one sketch into modules.

- `Current_NEXUS_Progress.ino` is the readable entry point for hardware setup and the main loop.
- `nexus_core.cpp` contains BLE, sensors, buttons, Pomodoro, Home, Focus, Health, and Unc behavior.
- `activity.h` and `activity.cpp` contain the MPU activity detection and the redesigned Activity OLED screen.
- `display_helpers.h` and `display_helpers.cpp` contain reusable drawing helpers: headers, centered text, Unc faces, progress bars, and stable `MM:SS` duration formatting.

The Activity flow implemented in source is Resting -> Move reminder -> Moving -> Complete. It uses 100 ms MPU polling, a 20-second demo inactivity threshold, a two-minute accumulated movement target, and a 900 ms completion state. All timing is `millis()` based.

The refactor compiled successfully and was uploaded to the ESP. The build used:

```sh
'/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli' compile --fqbn esp32:esp32:esp32 --build-path /private/tmp/nexus-activity-build '/Users/benduong/Documents/ChatGPT/NEXUS/Current_NEXUS_Progress'
```

The latest verified build used roughly 87% program storage and 12% RAM.
