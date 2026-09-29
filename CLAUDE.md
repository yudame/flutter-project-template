# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **production-ready Flutter architecture template** for small teams (2-5 people) using AI-assisted development. It contains a complete, working implementation in `lib/` (BLoC, offline queue, connectivity monitoring, Dio client, local cache) and architecture guides in `docs/`.

## Key Files

- `docs/architecture.md` - Reference guidelines and architecture patterns
- `docs/implemented.md` - Documentation for built features (connectivity, network, offline queue, BLoC patterns)
- `docs/setup_reference.md` - Environment setup and critical implementation patterns

## Architecture Principles

When implementing features based on this template:

1. **Two-layer architecture** - Presentation + Data only (no premature domain layer)
2. **Dart 3 sealed classes for BLoC** - Events and states use native Dart 3 `sealed class` hierarchies for instant compilation and pattern matching; Freezed is reserved for complex data models
3. **Connectivity-first** - Explicit handling of online/poor/offline states in repositories
4. **BLoC pattern** - State management with flutter_bloc + hydrated_bloc
5. **get_it** - Service locator for dependency injection
6. **Local cache persistence** - Repositories persist data through `LocalCacheService`

## Project Structure (When Implemented)

```
lib/
├── core/
│   ├── theme/              # App theme
│   ├── routes/             # go_router setup & auth guard
│   ├── network/            # DioClient, auth interceptor, offline queue
│   ├── database/           # LocalCacheService & DatabaseService interface
│   ├── connectivity/       # ConnectivityBloc & service
│   ├── di/                 # get_it configuration
│   └── utils/              # Result sealed class, mixins
├── features/
│   └── [feature_name]/
│       ├── data/
│       │   ├── models/     # Freezed data models
│       │   ├── repositories/
│       │   └── datasources/
│       └── presentation/
│           ├── bloc/       # BLoC + Dart 3 sealed events/states
│           ├── pages/
│           └── widgets/
└── shared/
```

## Common Commands

```bash
# Run app
flutter run -d ios
flutter run -d android

# Run tests
flutter test
flutter test test/path/to/specific_test.dart

# Code generation (freezed, json_serializable)
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs

# Clean and rebuild
flutter clean && flutter pub get

# Format code
dart format .
```

## Claude Skills & Commands

Skills are available in `.claude/skills/` and interactive commands in `.claude/commands/`:

- **`/test-chrome`** (`.claude/skills/flutter-test-chrome`): Run and test web app on Chrome with hot reload, ChromeDriver integration tests, or browser automation.
- **`/test-simulator`** (`.claude/skills/flutter-test-mobile-simulator`): Discover, boot, and run tests on iOS Simulators and Android Virtual Devices with screenshot verification.
- **`/new-bloc`**: Scaffold modern BLoC with Dart 3 sealed events and states.
- **`/new-feature`**: Scaffold complete feature module (model, repo, BLoC, page, tests).
- **`/run-tests`**: Execute unit, widget, and integration tests across web and mobile.

## Key Patterns

### Connectivity-Aware Repository
Repositories should handle three states: online (full API), poor (short timeouts + cache fallback), offline (cache only).

### Result Type
Use `Result<T>` pattern with success/failure/loading variants instead of throwing exceptions.

### Offline Queue
Use Hive with command pattern (RequestType enum + params map) for serializable queued requests.

### BLoC Testing
Target 90%+ coverage on BLoCs using bloc_test and mocktail.

### Database Pattern (Planned)
Core principle: `User → owns many → Documents (with optional media)`. Use abstract `DatabaseService` interface so repositories don't depend on Firebase/Supabase directly. Combine remote database with local Hive cache for offline support. **Note: Not yet implemented - see architecture.md for plan.**

## Tech Stack Reference

- State: flutter_bloc, hydrated_bloc, freezed
- Navigation: go_router
- Network: dio, connectivity_plus, dio_cache_interceptor
- Database: firebase_core, cloud_firestore, firebase_storage (or supabase_flutter)
- Local storage: hive, flutter_secure_storage, shared_preferences
- DI: get_it
- Monitoring: sentry_flutter
- Testing: bloc_test, mocktail
