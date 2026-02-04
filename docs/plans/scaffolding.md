# Plan: Project Scaffolding Script & Claude Commands

## Goal

Create tooling to rapidly scaffold new projects and features following template conventions. Enable:
- New project setup in < 5 minutes
- New feature scaffolding in < 1 minute
- Consistent structure across all generated code

## Current State

- Template has established patterns (see `lib/features/home/` for reference)
- One Claude command exists (`prime.md` for reading docs)
- No scaffolding scripts
- No feature generation tools
- Makefile exists but no scaffold targets

## Approach

Create a set of **Claude commands** that generate code following existing patterns. These are more flexible than shell scripts for code generation because Claude can:
- Understand context (existing models, imports)
- Generate appropriate test files
- Adapt to variations (with/without certain fields)

Also create a **post-clone setup script** and **Makefile targets** for common operations.

---

## Files to Create

### 1. `.github/TEMPLATE_SETUP.md`
Post-clone checklist for new projects:
```markdown
# Template Setup Checklist

After creating a new repository from this template:

## 1. Rename the Package
- [ ] Update `name` in `pubspec.yaml`
- [ ] Rename `lib/flutter_project_template` to your package name
- [ ] Update all imports

## 2. Configure App Identity
- [ ] Update `CFBundleIdentifier` in `ios/Runner/Info.plist`
- [ ] Update `applicationId` in `android/app/build.gradle`
- [ ] Update app name in `AndroidManifest.xml` and `Info.plist`

## 3. Set Up Environment
- [ ] Copy `.env.example` to `.env`
- [ ] Configure `API_BASE_URL`
- [ ] Set up Sentry DSN (optional)

## 4. Firebase Setup (if using)
- [ ] Create Firebase project
- [ ] Add `google-services.json` to `android/app/`
- [ ] Add `GoogleService-Info.plist` to `ios/Runner/`

## 5. Run Initial Setup
```bash
make setup  # Install dependencies and run code generation
```

## 6. Verify
```bash
make test   # Run tests
make run    # Run app
```
```

### 2. `scripts/setup.sh`
Initial project setup script:
```bash
#!/bin/bash
set -e

echo "🚀 Setting up Flutter project..."

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Check Flutter version
flutter --version

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Run code generation
echo "⚙️ Running code generation..."
flutter pub run build_runner build --delete-conflicting-outputs

# Run analysis
echo "🔍 Running analysis..."
flutter analyze --no-fatal-infos

# Run tests
echo "🧪 Running tests..."
flutter test

echo "✅ Setup complete! Run 'make run' to start the app."
```

### 3. `.claude/commands/new-feature.md`
```markdown
Scaffold a new feature module following the template's two-layer architecture.

## Input Required
- Feature name (e.g., "profile", "settings", "orders")

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
    └── widgets/

test/features/{name}/
├── data/
│   └── repositories/{name}_repository_test.dart
└── presentation/
    └── bloc/{name}_bloc_test.dart
```

## Generation Rules

1. **Model**: Use Freezed with JSON serialization, include `id`, `createdAt`, `updatedAt`
2. **Repository**: Implement connectivity-aware pattern from `item_repository.dart`
3. **BLoC**: Use `ConnectivityAwareBlocMixin`, implement load/create/update/delete
4. **Events**: Freezed union with standard CRUD events
5. **States**: Freezed union with initial/loading/loaded/error states
6. **Page**: BlocProvider + BlocBuilder scaffold
7. **Tests**: Mock repository, test all BLoC state transitions

## After Generation
1. Register repository in `lib/core/di/injection.dart`
2. Add route in `lib/core/routes/app_router.dart`
3. Run `flutter pub run build_runner build --delete-conflicting-outputs`
4. Run `flutter test` to verify
```

### 4. `.claude/commands/new-model.md`
```markdown
Create a new Freezed model with JSON serialization.

## Input Required
- Model name (PascalCase, e.g., "UserProfile", "Order")
- Fields (name: type pairs)

## Template

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '{snake_name}.freezed.dart';
part '{snake_name}.g.dart';

@freezed
abstract class {ModelName} with _${ModelName} {
  const factory {ModelName}({
    required String id,
    // ... fields from input
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _{ModelName};

  factory {ModelName}.fromJson(Map<String, dynamic> json) =>
      _${ModelName}FromJson(json);
}
```

## After Generation
1. Run `flutter pub run build_runner build --delete-conflicting-outputs`
2. Import in repository/bloc as needed
```

### 5. `.claude/commands/new-bloc.md`
```markdown
Create a new BLoC with Freezed events and states.

## Input Required
- BLoC name (e.g., "Profile", "Settings")
- Associated model (if any)
- Custom events needed (beyond standard CRUD)

## Files Created

### {name}_bloc.dart
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/connectivity/connectivity_bloc.dart';
import '../../../../core/connectivity/connectivity_state.dart';
import '../../../../core/utils/connectivity_aware_mixin.dart';
import '../../../../core/utils/result.dart';

part '{name}_event.dart';
part '{name}_state.dart';
part '{name}_bloc.freezed.dart';

class {Name}Bloc extends Bloc<{Name}Event, {Name}State>
    with ConnectivityAwareBlocMixin {
  @override
  final ConnectivityBloc connectivityBloc;

  {Name}Bloc({required this.connectivityBloc})
      : super(const {Name}State.initial()) {
    initConnectivityListener();

    on<{Name}Event>((event, emit) async {
      await event.when(
        load: () => _onLoad(emit),
        // ... other handlers
      );
    });
  }

  @override
  void onConnectivityChanged(ConnectivityState state) {
    if (state is ConnectivityOnline) {
      add(const {Name}Event.load());
    }
  }

  Future<void> _onLoad(Emitter<{Name}State> emit) async {
    emit(const {Name}State.loading());
    // TODO: Implement
    emit(const {Name}State.loaded());
  }
}
```

### {name}_event.dart
```dart
part of '{name}_bloc.dart';

@freezed
class {Name}Event with _${Name}Event {
  const factory {Name}Event.load() = _Load;
  // Add more events as needed
}
```

### {name}_state.dart
```dart
part of '{name}_bloc.dart';

@freezed
class {Name}State with _${Name}State {
  const factory {Name}State.initial() = _Initial;
  const factory {Name}State.loading() = _Loading;
  const factory {Name}State.loaded(/* data */) = _Loaded;
  const factory {Name}State.error(String message) = _Error;
}
```

## After Generation
1. Register in DI if needed
2. Run `flutter pub run build_runner build --delete-conflicting-outputs`
3. Add BlocProvider in widget tree
```

### 6. `.claude/commands/new-repository.md`
```markdown
Create a connectivity-aware repository.

## Input Required
- Repository name (e.g., "User", "Order")
- Associated model
- API endpoints (optional - can use mock)

## Template

```dart
import 'package:get_it/get_it.dart';

import '../../../core/connectivity/connectivity_bloc.dart';
import '../../../core/connectivity/connectivity_state.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/offline_queue.dart';
import '../../../core/utils/result.dart';
import '../models/{model}.dart';

class {Name}Repository {
  final DioClient _client;
  final OfflineQueue _offlineQueue;
  final ConnectivityBloc _connectivityBloc;

  // Local cache
  List<{Model}>? _cachedItems;

  {Name}Repository({
    DioClient? client,
    OfflineQueue? offlineQueue,
    ConnectivityBloc? connectivityBloc,
  })  : _client = client ?? GetIt.I<DioClient>(),
        _offlineQueue = offlineQueue ?? GetIt.I<OfflineQueue>(),
        _connectivityBloc = connectivityBloc ?? GetIt.I<ConnectivityBloc>();

  Future<Result<List<{Model}>>> getItems() async {
    final connectivity = _connectivityBloc.state;

    if (connectivity is ConnectivityOffline) {
      // Return cached data when offline
      return _cachedItems != null
          ? Result.success(_cachedItems!)
          : const Result.failure('No cached data available');
    }

    try {
      // TODO: Implement API call
      // final response = await _client.get('/items');
      // final items = (response.data as List)
      //     .map((json) => {Model}.fromJson(json))
      //     .toList();
      // _cachedItems = items;
      // return Result.success(items);

      return const Result.failure('Not implemented');
    } catch (e) {
      // Return cache on error if available
      if (_cachedItems != null) {
        return Result.success(_cachedItems!);
      }
      return Result.failure(e.toString());
    }
  }

  // Add create, update, delete methods following same pattern
}
```

## After Generation
1. Register in `lib/core/di/injection.dart`
2. Inject into BLoC
3. Implement actual API calls or keep mock for development
```

### 7. `.claude/commands/new-widget.md`
```markdown
Create a reusable widget with optional test.

## Input Required
- Widget name (e.g., "UserAvatar", "StatusBadge")
- Props/parameters needed
- Whether to include test file

## Template

```dart
import 'package:flutter/material.dart';

class {WidgetName} extends StatelessWidget {
  // Props
  final String title;
  final VoidCallback? onTap;

  const {WidgetName}({
    super.key,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return // TODO: Implement widget
  }
}
```

## Location Rules
- Feature-specific: `lib/features/{feature}/presentation/widgets/`
- Shared/reusable: `lib/shared/widgets/`

## After Generation
Consider if widget should be added to a widget catalog or storybook
```

### 8. Update `Makefile`
Add scaffold targets:
```makefile
# === Scaffolding ===

setup: ## Initial project setup
	./scripts/setup.sh

feature: ## Create new feature (use with NAME=feature_name)
	@echo "Use Claude command: /new-feature $(NAME)"

model: ## Create new model (use with NAME=ModelName)
	@echo "Use Claude command: /new-model $(NAME)"

bloc: ## Create new BLoC (use with NAME=BlocName)
	@echo "Use Claude command: /new-bloc $(NAME)"
```

### 9. Update `README.md`
Add scaffolding section:
```markdown
## Creating New Features

This template includes Claude commands for rapid scaffolding:

| Command | Description |
|---------|-------------|
| `/new-feature` | Scaffold complete feature module |
| `/new-model` | Create Freezed model |
| `/new-bloc` | Create BLoC with events/states |
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
```

---

## What We're NOT Doing

- **No interactive shell script for project rename** — too error-prone, use checklist instead
- **No code generation binary** — Claude commands are more flexible and context-aware
- **No VS Code extension** — overhead not justified for template
- **No GUI scaffolding tool** — command line is sufficient

## Structure After Implementation

```
flutter-project-template/
├── .github/
│   └── TEMPLATE_SETUP.md
├── .claude/
│   └── commands/
│       ├── prime.md                # Existing
│       ├── new-feature.md
│       ├── new-model.md
│       ├── new-bloc.md
│       ├── new-repository.md
│       └── new-widget.md
├── scripts/
│   └── setup.sh
├── Makefile                        # Updated
└── README.md                       # Updated
```

## Estimated Work

~9 files. Mostly Claude command templates. The commands reference existing patterns in the codebase. One focused session.
