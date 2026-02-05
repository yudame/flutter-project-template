Scaffold a new feature module following the template's two-layer architecture.

## Input Required

Ask for:
- **Feature name** (lowercase, e.g., "profile", "settings", "orders")

## What Gets Created

```
lib/features/{name}/
├── data/
│   ├── models/{name}.dart              # Freezed model
│   └── repositories/{name}_repository.dart  # Connectivity-aware repo
└── presentation/
    ├── bloc/
    │   ├── {name}_bloc.dart
    │   ├── {name}_event.dart           # Freezed events
    │   └── {name}_state.dart           # Freezed states
    ├── pages/{name}_page.dart
    └── widgets/                        # Empty, for feature widgets

test/features/{name}/
├── data/
│   └── repositories/{name}_repository_test.dart
└── presentation/
    └── bloc/{name}_bloc_test.dart
```

## Generation Rules

Use existing `lib/features/home/` as the reference pattern:

1. **Model** (`data/models/{name}.dart`):
   - Use Freezed with `@freezed` annotation
   - Include JSON serialization with `factory fromJson`
   - Standard fields: `id`, `createdAt`, `updatedAt?`
   - Add domain-specific fields based on feature

2. **Repository** (`data/repositories/{name}_repository.dart`):
   - Follow `item_repository.dart` pattern exactly
   - Inject `DioClient`, `OfflineQueue`, `ConnectivityBloc`
   - Implement connectivity-aware data fetching
   - Include local cache field
   - Handle offline gracefully

3. **BLoC** (`presentation/bloc/{name}_bloc.dart`):
   - Use `ConnectivityAwareBlocMixin`
   - Accept repository and `ConnectivityBloc` in constructor
   - Initialize connectivity listener
   - Implement handlers for all events

4. **Events** (`presentation/bloc/{name}_event.dart`):
   - Freezed union with `part of` directive
   - Standard events: `load`, `refresh`, `create{Name}`, `update{Name}`, `delete{Name}`

5. **States** (`presentation/bloc/{name}_state.dart`):
   - Freezed union with `part of` directive
   - States: `initial`, `loading`, `loaded(List<{Model}>)`, `error(String)`

6. **Page** (`presentation/pages/{name}_page.dart`):
   - `BlocProvider` at top level
   - `BlocBuilder` for state-based rendering
   - Handle all state variants (loading, loaded, error)
   - Use shared widgets (`LoadingIndicator`, `ErrorView`, etc.)

7. **Tests**:
   - BLoC test: Mock repository, test all state transitions
   - Use `bloc_test` package and `mocktail`
   - Follow patterns from `home_bloc_test.dart`

## After Generation

Remind user to:
1. Register repository in `lib/core/di/injection.dart`:
   ```dart
   getIt.registerLazySingleton<{Name}Repository>(() => {Name}Repository());
   ```

2. Add route in `lib/core/routes/app_router.dart`:
   ```dart
   GoRoute(
     path: '/{name}',
     builder: (context, state) => const {Name}Page(),
   ),
   ```

3. Run code generation:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. Run tests to verify:
   ```bash
   flutter test test/features/{name}/
   ```
