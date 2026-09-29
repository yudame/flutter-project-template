Run and test the Flutter application on Google Chrome.

## Usage
`/test-chrome [options]`

## Options
- `--port=<port>`: Specify web port (default: 8080)
- `--e2e`: Run automated integration tests with ChromeDriver instead of launching interactive browser
- `--no-web-security`: Disable browser CORS restrictions for local API debugging
- `--responsive`: Open multiple viewports (Mobile, Tablet, Desktop)

## Process

### Option 1: Interactive Browser Run
```bash
flutter run -d chrome --web-port=8080
```
- With disabled CORS:
  ```bash
  flutter run -d chrome --web-port=8080 --web-browser-flag "--disable-web-security" --web-browser-flag "--user-data-dir=/tmp/chrome_dev"
  ```

### Option 2: Automated End-to-End Integration Tests
1. Start ChromeDriver:
   ```bash
   chromedriver --port=4444 &
   ```
2. Run test target:
   ```bash
   flutter drive \
     --driver=test_driver/integration_test.dart \
     --target=integration_test/web_smoke_test.dart \
     -d chrome
   ```

### Option 3: Browser Automation via CLI
1. Start local server:
   ```bash
   flutter run -d web-server --web-port=8080 &
   ```
2. Interact using `agent-browser`:
   ```bash
   agent-browser open http://localhost:8080
   agent-browser snapshot -i
   ```

## Checks Performed
- [ ] Application compiles and bundles for Web without errors
- [ ] No unhandled JavaScript console exceptions
- [ ] Layout responds cleanly to viewport resizing
- [ ] Network requests complete without CORS rejections
