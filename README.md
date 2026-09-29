# Flutter Project Template

**Production-ready Flutter project template with BLoC, connectivity-first architecture**

A complete, runnable Flutter project template designed for 2-5 person teams leveraging AI code generation tools. Includes working code examples for all documented patterns.

## Quick Start

```bash
# Clone and rename
git clone https://github.com/your-org/flutter-project-template.git my-app
cd my-app

# Update package name
# Edit pubspec.yaml: change 'flutter_template' to 'my_app'
# Update imports in lib/ files

# Install dependencies
flutter pub get

# Generate code (freezed, json_serializable)
make gen
# or: dart run build_runner build --delete-conflicting-outputs

# Run
flutter run
```

## What's Included

This template is a **fully functional Flutter project** with:

### Core Infrastructure
- **Dependency Injection** - `get_it` configured in `lib/core/di/`
- **Network Layer** - Dio client with auth interceptor in `lib/core/network/`
- **Connectivity Management** - Online/poor/offline states in `lib/core/connectivity/`
- **Offline Queue** - Request queuing with retry in `lib/core/network/`
- **Routing** - go_router setup in `lib/core/routes/`
- **Theming** - Material 3 theme in `lib/core/theme/`

### Example Feature
- **Home Feature** - Complete BLoC example in `lib/features/home/`
  - Freezed model (`Item`)
  - Repository with connectivity awareness
  - BLoC with events/states
  - UI with pages and widgets

### Shared Components
- **Widgets** - Reusable UI components in `lib/shared/widgets/`
  - `ConnectivityBanner` - Shows connection status
  - `LoadingIndicator` - Centered loading spinner
  - `ErrorView` - Error display with retry
  - `EmptyState` - Empty list state

### Testing
- **BLoC Tests** - Example tests in `test/features/home/`
- **Unit Tests** - Result type tests in `test/core/utils/`
- **Widget Tests** - Widget tests in `test/shared/widgets/`

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── di/                   # Dependency injection (get_it)
│   ├── connectivity/         # ConnectivityBloc & service
│   ├── network/              # DioClient, auth, offline queue
│   ├── routes/               # go_router configuration
│   ├── theme/                # App theme
│   └── utils/                # Result type, mixins
├── features/
│   └── home/                 # Example feature
│       ├── data/
│       │   ├── models/       # Freezed models
│       │   └── repositories/ # Data repositories
│       └── presentation/
│           ├── bloc/         # BLoC + events + states
│           ├── pages/        # Screen widgets
│           └── widgets/      # Feature widgets
├── shared/
│   └── widgets/              # Reusable components
└── test/                     # Test files
```

## Available Commands

```bash
make help          # Show all commands
make setup         # Install deps + generate code
make gen           # Run code generation
make watch         # Code generation watch mode
make test          # Run all tests
make test-coverage # Run tests with coverage report
make analyze       # Run static analysis
make format        # Format code
make run           # Run in debug mode
make clean         # Clean build artifacts
```

## Customizing for Your Project

### 1. Rename the Package

Update `pubspec.yaml`:
```yaml
name: your_app_name
```

Update imports throughout `lib/` from `flutter_template` to `your_app_name`.

### 2. Configure API Base URL

Edit `lib/core/network/dio_client.dart` or set environment variable:
```bash
flutter run --dart-define=API_BASE_URL=https://your-api.com
```

### 3. Add Your Features

Copy the `home` feature structure:
```
lib/features/your_feature/
├── data/
│   ├── models/your_model.dart
│   └── repositories/your_repository.dart
└── presentation/
    ├── bloc/your_bloc.dart
    ├── pages/your_page.dart
    └── widgets/
```

### 4. Register Dependencies

Add to `lib/core/di/injection.dart`:
```dart
getIt.registerLazySingleton(() => YourRepository(...));
getIt.registerFactory(() => YourBloc(getIt<YourRepository>(), ...));
```

### 5. Add Routes

Update `lib/core/routes/app_router.dart`:
```dart
GoRoute(
  path: '/your-feature',
  name: 'your-feature',
  builder: (context, state) => const YourPage(),
),
```

## Creating New Features

This template includes Claude commands and specialized skills in `.claude/` for rapid scaffolding and testing:

### Claude Slash Commands

| Command | Description |
|---------|-------------|
| `/new-feature` | Scaffold complete feature module (model, repo, BLoC, page, tests) |
| `/new-model` | Create Freezed model with JSON serialization |
| `/new-bloc` | Create BLoC with Dart 3 sealed class events/states |
| `/new-repository` | Create connectivity-aware repository |
| `/new-widget` | Create reusable widget |
| `/test-chrome` | Launch, inspect, and run integration/unit tests on Google Chrome |
| `/test-simulator` | Boot, manage, test, and deep-link iOS Simulator & Android Emulator |
| `/run-tests` | Run full test suite (unit, BLoC, widget, integration) with coverage |

### Claude Agent Skills (`.claude/skills/`)

- **`flutter-test-chrome`** - Workflows for testing Flutter web in Chrome (headless, ChromeDriver, viewport simulation, console logs).
- **`flutter-test-mobile-simulator`** - Automation for discovering, booting, installing, testing, and debugging on iOS Simulators (`xcrun simctl`) and Android Virtual Devices (`emulator`, `adb`).
- **`flutter-build-and-test`** - Standardized build verification, static analysis, code generation, and test execution.

### Example: Adding a Profile Feature

```
/new-feature profile
```

This creates:
- `lib/features/profile/` with data and presentation layers (using Dart 3 sealed classes)
- `test/features/profile/` with BLoC and repository tests
- All following template conventions

After scaffolding, register the feature in DI and add routes.

## Tech Stack

| Category | Package | Purpose |
|----------|---------|---------|
| State | `flutter_bloc` | BLoC pattern |
| State | `hydrated_bloc` | Persistent state |
| Models | `freezed` | Immutable models |
| Navigation | `go_router` | Declarative routing |
| Network | `dio` | HTTP client |
| Connectivity | `connectivity_plus` | Network monitoring |
| Storage | `hive` | Local NoSQL database |
| Storage | `flutter_secure_storage` | Encrypted storage |
| DI | `get_it` | Service locator |
| Monitoring | `sentry_flutter` | Error tracking |
| Testing | `bloc_test`, `mocktail` | Testing utilities |

## Documentation

- **[Architecture Guide](docs/architecture.md)** - Complete architecture patterns
- **[Setup Reference](docs/setup_reference.md)** - Setup and implementation details
- **[Testing Guide](docs/testing.md)** - Testing patterns and conventions
- **[Localization Guide](docs/localization.md)** - i18n setup and usage

## Key Patterns

### Connectivity-Aware Repository
```dart
Future<Result<Data>> fetchData(String id) async {
  if (_connectivity.isOffline) return _tryCache(id);
  if (_connectivity.isPoor) {
    try {
      return await _api.fetch(id).timeout(Duration(seconds: 5));
    } catch (e) {
      return _tryCache(id);
    }
  }
  return _fetchFromApi(id);
}
```

### BLoC with Dart 3 Sealed Classes
```dart
sealed class MyEvent {
  const MyEvent();
  const factory MyEvent.load() = MyLoad;
  const factory MyEvent.refresh() = MyRefresh;
}

sealed class MyState {
  const MyState();
  const factory MyState.initial() = MyInitial;
  const factory MyState.loading() = MyLoading;
  const factory MyState.loaded(Data data) = MyLoaded;
  const factory MyState.error(String message) = MyError;
}
```

### Offline Queue
```dart
if (_connectivity.isOffline) {
  await _offlineQueue.add(RequestType.createItem, params);
  return optimisticResult;
}
```

## Testing

### Unit and BLoC Tests

```bash
# Run all unit and widget tests
flutter test

# Run with coverage report
flutter test --coverage

# Run a specific test file
flutter test test/features/home/presentation/bloc/home_bloc_test.dart
```

### Web Testing via Google Chrome

```bash
# Run web unit tests in Chrome
flutter test --platform chrome

# Run integration tests against headless Chrome
chromedriver --port=4444 &
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d chrome

# Launch app in Chrome with debugging
flutter run -d chrome
```
*See [.claude/skills/flutter-test-chrome/SKILL.md](.claude/skills/flutter-test-chrome/SKILL.md) and `/test-chrome` for full web automation details.*

### Mobile Simulator Testing (iOS & Android)

```bash
# List available simulators and devices
flutter devices
flutter emulators

# Launch an iOS Simulator
open -a Simulator
# or: xcrun simctl boot <device-udid>

# Launch an Android Emulator
flutter emulators --launch <emulator-id>

# Run integration tests on the active simulator
flutter test integration_test/app_test.dart -d <device-id>
```
*See [.claude/skills/flutter-test-mobile-simulator/SKILL.md](.claude/skills/flutter-test-mobile-simulator/SKILL.md) and `/test-simulator` for deep-linking, screenshot capture, and ADB/simctl automation.*

## Production Checklist

- [ ] Update package name in `pubspec.yaml`
- [ ] Configure `API_BASE_URL` in `lib/core/network/dio_client.dart`
- [ ] Set up Sentry (`SENTRY_DSN`)
- [ ] Configure app icons and splash screen
- [ ] Configure Firebase or backend services (if needed)
- [ ] Set up CI/CD workflows (`.github/workflows/`)
- [x] Android minSdk set to 23 (configured in `android/app/build.gradle.kts`)

## Running

```bash
flutter pub get
flutter run
```

## License

MIT License - use freely in your projects.
