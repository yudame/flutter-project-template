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
# or: flutter pub run build_runner build --delete-conflicting-outputs

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

This template includes Claude commands for rapid scaffolding:

| Command | Description |
|---------|-------------|
| `/new-feature` | Scaffold complete feature module (model, repo, BLoC, page, tests) |
| `/new-model` | Create Freezed model with JSON serialization |
| `/new-bloc` | Create BLoC with Freezed events/states |
| `/new-repository` | Create connectivity-aware repository |
| `/new-widget` | Create reusable widget |

### Example: Adding a Profile Feature

```
/new-feature profile
```

This creates:
- `lib/features/profile/` with data and presentation layers
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

### BLoC with Freezed
```dart
@freezed
class MyEvent with _$MyEvent {
  const factory MyEvent.load() = _Load;
  const factory MyEvent.refresh() = _Refresh;
}

@freezed
class MyState with _$MyState {
  const factory MyState.initial() = _Initial;
  const factory MyState.loading() = _Loading;
  const factory MyState.loaded(Data data) = _Loaded;
  const factory MyState.error(String message) = _Error;
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

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/features/home/presentation/bloc/home_bloc_test.dart
```

## Production Checklist

- [ ] Update package name in `pubspec.yaml`
- [ ] Configure `API_BASE_URL`
- [ ] Set up Sentry (`SENTRY_DSN`)
- [ ] Configure app icons
- [ ] Set up splash screen
- [ ] Configure Firebase (if needed)
- [ ] Set up CI/CD
- [ ] Update Android minSdk to 23 (for flutter_secure_storage)

## Running

```bash
flutter pub get
flutter run
```

## License

MIT License - use freely in your projects.
