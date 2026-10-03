# iPhone development installation

## Setup on this Mac

- Flutter 3.47.6: `~/development/flutter`
- Xcode 27.0: `/Applications/Xcode.app`
- Signing: the owner's Apple Personal Team, with automatic signing enabled for Runner.
- Bundle ID: `com.uncstechstore.uncpanion`
- The BLE plugin uses the project's existing Swift Package Manager integration. CocoaPods was not required for this build.

The Mac's default developer directory still points to Command Line Tools, and an older Git can shadow native Git. Use this environment when building:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
cd /Users/benduong/Documents/ChatGPT/NEXUS/app
flutter devices
flutter run --release -d <iphone-device-id>
```

Connect and unlock the iPhone first. Release mode allows opening the app after unplugging the phone. On a first installation, iOS may require trusting your developer profile in Settings → General → VPN & Device Management. Follow any Developer Mode prompt on the device if one appears.

## Installation record — 4 October 2026

- Unsigned and signed release builds completed successfully.
- Apple device tooling confirmed installation on the connected iPhone.
- Local code-signature verification passed.
- First launch was blocked by iOS's developer-profile trust requirement. After trusting the profile, the user confirmed that Uncpanion opens successfully.
- The current provisioning profile expires at **00:34 on 11 October 2026 (Vietnam time)**. Rebuild and reinstall to renew this Personal Team installation.
- This does not publish the app to the App Store or TestFlight. Deferred regression tests and ESP/BLE checks have not been run.
