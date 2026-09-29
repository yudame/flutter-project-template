---
name: flutter-test-mobile-simulator
description: Boot, run, test, and capture screenshots on iOS Simulators and Android Emulators for Flutter apps.
---

# Testing Flutter Apps on Mobile Simulators & Emulators

This skill provides step-by-step guidance for managing iOS Simulators and Android Virtual Devices (AVDs), running Flutter applications, executing automated integration tests, simulating edge cases (offline/deep links), and capturing verification screenshots.

## Table of Contents
1. [Simulator & Emulator Discovery](#simulator--emulator-discovery)
2. [Booting & Managing Devices](#booting--managing-devices)
3. [Running the Flutter App](#running-the-flutter-app)
4. [Automated Integration Testing](#automated-integration-testing)
5. [Capturing Screenshots & Videos](#capturing-screenshots--videos)
6. [Simulating Network States & Deep Links](#simulating-network-states--deep-links)
7. [Common Troubleshooting](#common-troubleshooting)

---

## Simulator & Emulator Discovery

List all detected targets recognized by Flutter:

```bash
flutter devices
```

### iOS Simulators (`simctl`)
```bash
# List available iOS runtimes and devices
xcrun simctl list devices available

# Find booted devices
xcrun simctl list devices | grep "Booted"
```

### Android Emulators (`emulator` & `adb`)
```bash
# List installed Android Virtual Devices (AVDs)
emulator -list-avds

# List active adb devices
adb devices
```

---

## Booting & Managing Devices

### iOS Simulator
```bash
# Open Simulator UI app
open -a Simulator

# Boot a specific device by name or UDID
xcrun simctl boot "iPhone 16"
# or by UDID:
xcrun simctl boot <DEVICE_UUID>

# Shutdown a device
xcrun simctl shutdown booted

# Reset/erase simulator data
xcrun simctl erase booted
```

### Android Emulator
```bash
# Start an emulator in the background
emulator -avd <AVD_NAME> -no-boot-anim -netdelay none -netspeed full &

# Wait for emulator to finish booting
adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done;'
```

---

## Running the Flutter App

Once the simulator or emulator is booted, launch the application:

```bash
# Auto-select the only booted mobile device
flutter run

# Target iOS simulator specifically
flutter run -d ios
# or by ID:
flutter run -d <DEVICE_UUID>

# Target Android emulator specifically
flutter run -d android
# or by ID:
flutter run -d emulator-5554

# Run with environment variables (e.g. mock API base URL)
flutter run -d ios --dart-define=API_BASE_URL=https://staging-api.example.com
```

### Controls During Interactive Run:
- `r` — Hot reload.
- `R` — Hot restart (resets BLoC and widget states).
- `p` — Toggle debug painting (visualize layout boxes & overflows).
- `o` — Simulate Android / iOS platform rendering.
- `q` — Quit and terminate the application.

---

## Automated Integration Testing

Modern Flutter (Flutter 3.x+) runs integration tests directly on booted mobile simulators without needing a separate driver script:

### 1. Test File (`integration_test/app_flow_test.dart`)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_template/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full app smoke test on mobile simulator', (tester) async {
    await tester.pumpWidget(const FlutterTemplateApp());
    await tester.pumpAndSettle();

    // Verify initial home screen
    expect(find.text('Flutter Template'), findsOneWidget);

    // Trigger item creation
    final fab = find.byType(FloatingActionButton);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Title'), findsOneWidget);
  });
}
```

### 2. Execute on Booted Device
```bash
# Run on currently booted device
flutter test integration_test/app_flow_test.dart

# Run on specific target
flutter test integration_test/app_flow_test.dart -d <DEVICE_ID>
```

---

## Capturing Screenshots & Videos

Visual evidence is essential for validating UI changes.

### iOS Simulator
```bash
# Save screenshot of booted simulator
xcrun simctl io booted screenshot ./screenshots/ios_home_screen.png

# Record video
xcrun simctl io booted recordVideo ./screenshots/demo.mp4
# (Press Ctrl+C to stop recording)
```

### Android Emulator
```bash
# Save screenshot
adb exec-out screencap -p > ./screenshots/android_home_screen.png

# Record screen
adb shell screenrecord /sdcard/demo.mp4 &
# To stop and pull:
adb pull /sdcard/demo.mp4 ./screenshots/demo.mp4
```

---

## Simulating Network States & Deep Links

### Testing Connectivity Changes (Online / Offline / Poor)

#### iOS Simulator:
Apple Developer provides the **Network Link Conditioner** to simulate 3G, LTE, and edge drops.
Quick CLI toggle for status bar appearance:
```bash
xcrun simctl status_bar booted override --dataNetwork wifi --wifiBars 3
```

#### Android Emulator (via `adb`):
```bash
# Simulate Airplane mode (Offline state)
adb shell cmd connectivity airplane-mode enable
adb shell svc wifi disable
adb shell svc data disable

# Restore Online state
adb shell cmd connectivity airplane-mode disable
adb shell svc wifi enable
adb shell svc data enable
```

### Testing Deep Links (`GoRouter`)

#### iOS Simulator:
```bash
xcrun simctl openurl booted "my-app://items/123"
```

#### Android Emulator:
```bash
adb shell am start -a android.intent.action.VIEW -d "my-app://items/123" com.example.flutter_template
```

---

## Common Troubleshooting

| Issue | Resolution |
|:---|:---|
| **`No connected devices`** | Verify device is booted using `xcrun simctl list devices \| grep Booted` or `adb devices`. Check `flutter doctor`. |
| **`minSdk 23 required` on Android** | Check `android/app/build.gradle.kts` has `minSdk = 23` configured. |
| **Pod install failure on iOS** | Run `cd ios && pod repo update && pod install && cd ..` |
| **CocoaPods missing** | Install via `sudo gem install cocoapods` or Homebrew. |
| **Rosetta / x86 vs arm64 on Mac** | Ensure terminal runs natively on arm64 (`uname -m` outputs `arm64`). |
