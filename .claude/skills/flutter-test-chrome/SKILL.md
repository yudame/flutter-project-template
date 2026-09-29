---
name: flutter-test-chrome
description: Test, debug, and automate Flutter Web applications in Google Chrome using ChromeDriver, headless integration tests, and browser automation tools.
---

# Testing Flutter Web Applications in Google Chrome

This skill provides step-by-step guidance for testing, profiling, and automating Flutter Web apps using Google Chrome, ChromeDriver, and browser automation tools (`agent-browser` or Chrome DevTools MCP).

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Interactive Running & Debugging](#interactive-running--debugging)
3. [Automated Integration Testing with ChromeDriver](#automated-integration-testing-with-chromedriver)
4. [Browser Automation & UI Inspection](#browser-automation--ui-inspection)
5. [Responsive & Cross-Device Viewport Testing](#responsive--cross-device-viewport-testing)
6. [Web-Specific Pitfalls & Fixes](#web-specific-pitfalls--fixes)

---

## Prerequisites

1. **Google Chrome** installed.
2. **Flutter Web Support** enabled:
   ```bash
   flutter config --enable-web
   flutter devices # Chrome should appear in the list
   ```
3. **ChromeDriver** (for automated E2E tests):
   ```bash
   # Install via Homebrew on macOS:
   brew install --cask chromedriver
   # Verify version matches Chrome:
   chromedriver --version
   ```

---

## Interactive Running & Debugging

### Launch in Chrome
Run the application target in Chrome with hot reload enabled:

```bash
# Standard debug launch
flutter run -d chrome

# Run on a fixed port (useful for consistent URLs and OAuth callbacks)
flutter run -d chrome --web-port=8080

# Disable web security (CORS) for local development against dev APIs
flutter run -d chrome --web-browser-flag "--disable-web-security" --web-browser-flag "--user-data-dir=/tmp/chrome_dev_test"

# Run with WebAssembly / CanvasKit renderer (Flutter 3.22+)
flutter run -d chrome --wasm
```

### Hot Reload & Restart in Chrome
- Press `r` in the terminal to trigger **hot reload**.
- Press `R` in the terminal to trigger **hot restart**.
- Open Chrome DevTools (`Cmd + Option + I`) to inspect console logs and network traffic.

---

## Automated Integration Testing with ChromeDriver

Integration tests for Flutter Web execute inside real Chrome instances via ChromeDriver and the `integration_test` package.

### 1. Ensure Dependencies in `pubspec.yaml`
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
```

### 2. Driver Entry Point (`test_driver/integration_test.dart`)
```dart
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
```

### 3. Example Web Integration Test (`integration_test/web_smoke_test.dart`)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_template/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App loads on web and navigates cleanly', (tester) async {
    await tester.pumpWidget(const FlutterTemplateApp());
    await tester.pumpAndSettle();

    // Verify main screen widgets render
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Test add item dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add Item'), findsWidgets);
  });
}
```

### 4. Running the Web Test
In terminal 1:
```bash
chromedriver --port=4444
```

In terminal 2:
```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/web_smoke_test.dart \
  -d chrome
```

---

## Browser Automation & UI Inspection

When testing a running Flutter Web app with CLI automation (e.g. `agent-browser`), follow this workflow:

1. **Start the Flutter Web server**:
   ```bash
   flutter run -d web-server --web-port=8080 &
   ```
2. **Open the browser**:
   ```bash
   agent-browser open http://localhost:8080
   ```
3. **Capture interactive snapshot**:
   ```bash
   agent-browser snapshot -i
   ```
4. **Interact with elements**:
   ```bash
   agent-browser click @e1
   agent-browser fill @e2 "Test Title"
   ```
5. **Inspect console errors**:
   - Check if any uncaught exceptions or CORS errors appear in stdout.

---

## Responsive & Cross-Device Viewport Testing

Flutter Web is used across mobile and desktop browsers. Test responsive layouts by launching Chrome with custom viewport dimensions:

```bash
# Mobile portrait view (e.g., iPhone 15 size 393x852)
flutter run -d chrome --web-browser-flag "--window-size=393,852"

# Tablet landscape view (e.g., iPad 1024x768)
flutter run -d chrome --web-browser-flag "--window-size=1024,768"

# Desktop Full HD view (1920x1080)
flutter run -d chrome --web-browser-flag "--window-size=1920,1080"
```

---

## Web-Specific Pitfalls & Fixes

| Issue | Cause | Fix |
|:---|:---|:---|
| **CORS errors on API calls** | Browser enforcement of Same-Origin Policy | Use `--web-browser-flag "--disable-web-security"` for local dev, or configure CORS on the backend |
| **`PathProviderException` / Missing dirs** | `getApplicationDocumentsDirectory()` unsupported on web | Guard directory lookups with `if (kIsWeb)` or use Web storage alternatives |
| **Fonts or icons not rendering** | CanvasKit font downloading blocked | Pass `--web-renderer html` or ensure network allows `fonts.gstatic.com` |
| **Browser back button loses state** | Browser history desynced from `GoRouter` | Ensure `GoRouter` uses `usePathUrlStrategy()` in `main.dart` |
