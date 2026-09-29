Run and test the Flutter application on an iOS Simulator or Android Emulator.

## Usage
`/test-simulator [platform] [options]`

## Arguments
- `ios`: Target iOS Simulator
- `android`: Target Android Virtual Device (AVD)

## Options
- `--e2e`: Execute automated integration tests on the booted device
- `--screenshot`: Capture a screenshot of the booted device upon launch
- `--reset`: Wipe simulator/emulator state before booting

## Process

### Step 1: Discover & Boot Device
For iOS:
```bash
# Check if device is already booted
xcrun simctl list devices | grep "Booted"

# Boot if not running
open -a Simulator
xcrun simctl boot "iPhone 16"
```

For Android:
```bash
# Check active adb devices
adb devices

# Boot emulator if not running
emulator -list-avds
emulator -avd <AVD_NAME> -no-boot-anim &
```

### Step 2: Run Application or Integration Tests
Interactive run:
```bash
flutter run -d ios      # iOS
flutter run -d android  # Android
```

Integration test run:
```bash
flutter test integration_test/app_flow_test.dart -d ios
# or
flutter test integration_test/app_flow_test.dart -d android
```

### Step 3: Capture Screenshot (Verification)
For iOS:
```bash
xcrun simctl io booted screenshot ./screenshots/ios_verification.png
```

For Android:
```bash
adb exec-out screencap -p > ./screenshots/android_verification.png
```

## Checks Performed
- [ ] Device boots and establishes debug connection
- [ ] App launches without missing native symbols or missing Gradle/CocoaPods dependencies
- [ ] No layout overflows (`RenderFlex`) on device screen size
- [ ] Back navigation and orientation switches work as expected
