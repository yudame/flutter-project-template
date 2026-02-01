# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **documentation-only Flutter architecture template** for small teams (2-5 people) using AI-assisted development. It contains no source code—only architecture guides and setup documentation to copy into new Flutter projects.

## Key Files

- `docs/architecture.md` - Reference guidelines + **planned features** (Database Layer)
- `docs/implemented.md` - Documentation for already-built features (connectivity, network, offline queue, BLoC patterns)
- `docs/setup_reference.md` - Environment setup and critical implementation patterns

## Architecture Principles

When implementing features based on this template:

1. **Two-layer architecture** - Presentation + Data only (no separate domain layer)
2. **Freezed everywhere** - Models, BLoC events, and states use sealed unions
3. **Connectivity-first** - Explicit handling of online/poor/offline states in repositories
4. **BLoC pattern** - State management with flutter_bloc + hydrated_bloc
5. **get_it** - Service locator for dependency injection

## Project Structure (When Implemented)

```
lib/
├── core/
│   ├── theme/              # App theme
│   ├── routes/             # go_router setup
│   ├── network/            # DioClient, offline queue
│   ├── database/           # DatabaseService, StorageService (Firebase/Supabase)
│   ├── connectivity/       # ConnectivityBloc & service
│   ├── di/                 # get_it configuration
│   └── utils/              # Logger, constants, extensions
├── features/
│   └── [feature_name]/
│       ├── data/
│       │   ├── models/     # Freezed models
│       │   ├── repositories/
│       │   └── datasources/
│       └── presentation/
│           ├── bloc/       # BLoC + Freezed events/states
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

# Code generation (freezed, json_serializable, hive)
flutter pub run build_runner build --delete-conflicting-outputs
flutter pub run build_runner watch --delete-conflicting-outputs

# Clean and rebuild
flutter clean && flutter pub get

# Format code (use instead of linting)
dart format .
```

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
