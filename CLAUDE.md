# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **source-bearing Flutter architecture template** for small teams (2-5 people) using AI-assisted development. It ships a real, runnable app under `lib/` alongside the architecture guides and setup documentation — use it as the starting point to copy into new Flutter projects.

## Key Files

- `docs/architecture.md` - Reference guidelines + **planned features** (Database Layer)
- `docs/implemented.md` - Documentation for already-built features (connectivity, network, offline queue, BLoC patterns)
- `docs/setup_reference.md` - Environment setup and critical implementation patterns
- `lib/` - The implemented source tree (see Project Structure below)

## Architecture Principles

This repository is organized around these principles:

1. **Two-layer architecture** - Presentation + Data only (no separate domain layer)
2. **Freezed everywhere** - Models, BLoC events, and states use sealed unions
3. **Connectivity-first** - Explicit handling of online/poor/offline states in repositories
4. **BLoC pattern** - State management with flutter_bloc + hydrated_bloc
5. **get_it** - Service locator for dependency injection

## Project Structure

```
lib/
├── main.dart              # App entry point
├── l10n/                  # Localization (app_en.arb, app_es.arb)
├── core/
│   ├── theme/             # AppTheme
│   ├── routes/            # go_router setup + auth_guard
│   ├── network/           # DioClient, offline queue, request executor, auth token manager + interceptor
│   ├── database/          # DatabaseService (interface), LocalCacheService, sync status, cached document
│   ├── connectivity/      # ConnectivityBloc & service
│   ├── auth/              # OPTIONAL auth layer (AuthRepository, AuthBloc) — see Optional Authentication
│   ├── analytics/         # AnalyticsService + NoopAnalyticsService (default)
│   ├── di/                # get_it configuration
│   └── utils/             # Result type, connectivity-aware mixin
├── features/
│   └── home/              # Example feature (data + presentation + BLoC)
└── shared/
    └── widgets/           # Reusable widgets (error view, connectivity banner, loading, empty state)
```

## Optional Authentication

The auth layer ships **unwired**. `lib/core/auth/` contains `AuthRepository`, `AuthBloc`, `AuthEvent`, and `AuthState`, and `AuthTokenManager` + `AuthInterceptor` exist under `lib/core/network/` — but the repository and BLoC are **not** registered in dependency injection (`lib/core/di/injection.dart` has the registrations commented out under an "Auth (uncomment after implementing AuthRepository)" block). Choose one:

- **Enable auth**: implement a concrete `AuthRepository` (the commented block references a `FirebaseAuthRepository` stub to write), then uncomment the `AuthRepository`/`AuthBloc` registrations in `lib/core/di/injection.dart` along with their `auth_bloc.dart`/`auth_repository.dart` imports. `AuthTokenManager`, `AuthInterceptor`, and `RequestExecutor` are already wired and ready once the repository exists.
- **Strip auth** (full removal): delete `lib/core/auth/`, `lib/core/routes/auth_guard.dart`, and `test/core/auth/`; remove `AuthTokenManager` from `lib/core/di/injection.dart`, drop the `authManager` dependency from `DioClient` and `RequestExecutor`, delete `auth_interceptor.dart` and `auth_token_manager.dart`, and remove the `auth_exception.dart` import + `on AuthException` catch in `offline_queue.dart`. (The stale, commented-out auth references in `lib/core/routes/app_router.dart` — the `auth_guard`/`auth_bloc`/`injection` imports and the commented `redirect:` block — can also be cleaned up.)

See [docs/architecture.md](docs/architecture.md) → Optional Authentication for details.

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
