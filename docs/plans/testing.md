# Plan: Testing Infrastructure & Coverage Documentation

## Goal

Expand testing documentation and tooling to ensure consistent, high-quality test coverage across projects using this template. Provide clear guidance on what to test, how to test it, and automation to enforce standards.

## Current State

- 3 test files exist as examples:
  - `test/core/utils/result_test.dart` - Unit tests for Result type
  - `test/features/home/presentation/bloc/home_bloc_test.dart` - BLoC tests with mocktail
  - `test/shared/widgets/error_view_test.dart` - Widget test
- Testing patterns documented briefly in `docs/implemented.md`
- `Makefile` has basic `test` and `test-coverage` targets
- No test helpers, fixtures, or factories
- No CI coverage enforcement

## Approach

Create comprehensive testing documentation that explains the **why** behind testing decisions, plus practical tooling to make testing easier:

1. Documentation explaining testing philosophy and patterns
2. Test helpers and utilities for common setup
3. Fixtures and factories for test data
4. Shell scripts for coverage workflows
5. Claude commands for generating tests

---

## Files to Create

### 1. `docs/testing.md`
Comprehensive testing documentation:

```markdown
# Testing Guide

## Philosophy

Test behavior, not implementation. Focus testing effort where it provides the most value:

| Layer | Coverage Target | Why |
|-------|-----------------|-----|
| BLoC | 90%+ | Business logic lives here. High value. |
| Repository | 70%+ | Data flow and error handling. Medium-high value. |
| Utils/Core | 80%+ | Shared code affects everything. Medium-high value. |
| Widgets | Selective | Only critical user flows. Low-medium value. |
| Models | 0% | Generated code (Freezed). Zero value. |

## Test Types

### Unit Tests (BLoC, Repository, Utils)
- Fast, isolated, no Flutter framework needed
- Use `flutter_test` + `bloc_test` + `mocktail`
- Run with `flutter test`

### Widget Tests
- Test widget behavior, not pixel-perfect rendering
- Use `flutter_test` + `WidgetTester`
- Mock dependencies, test user interactions

### Integration Tests (Optional)
- Full app flow tests
- Use `integration_test` package
- Run on device/emulator

### Golden Tests (Optional)
- Screenshot comparison for UI consistency
- Use `golden_toolkit` package
- Useful for design systems

## Patterns

### BLoC Testing with bloc_test

```dart
blocTest<MyBloc, MyState>(
  'description of expected behavior',
  build: () {
    // Set up mocks
    when(() => mockRepo.getData()).thenAnswer((_) async => Result.success(data));
    return MyBloc(repository: mockRepo);
  },
  seed: () => MyState.loaded(existingData),  // Optional: set initial state
  act: (bloc) => bloc.add(MyEvent.load()),
  expect: () => [
    MyState.loading(),
    MyState.loaded(data),
  ],
  verify: (_) {
    verify(() => mockRepo.getData()).called(1);
  },
);
```

### Mocking with mocktail

```dart
class MockMyRepository extends Mock implements MyRepository {}

setUpAll(() {
  registerFallbackValue(FakeMyModel());  // For any() matchers
});

setUp(() {
  mockRepo = MockMyRepository();
  when(() => mockRepo.stream).thenAnswer((_) => const Stream.empty());
});
```

### Test Data Factories

```dart
// Use factories for consistent test data
final testItem = ItemFactory.create(title: 'Custom Title');
final testItems = ItemFactory.createList(5);
```

## What NOT to Test

- Generated code (*.freezed.dart, *.g.dart)
- Third-party packages
- Trivial getters/setters
- Private methods (test through public API)
- UI layout (unless critical to UX)

## Running Tests

```bash
make test           # Run all tests
make test-coverage  # Run with coverage report
make test-watch     # Watch mode for TDD
```

## Coverage Reports

Coverage reports are generated in `coverage/` directory:
- `coverage/lcov.info` - Raw coverage data
- `coverage/html/` - HTML report (open index.html)

View coverage: `open coverage/html/index.html`
```

### 2. `test/helpers/test_helpers.dart`
Common test setup utilities:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_template/core/connectivity/connectivity_bloc.dart';
import 'package:flutter_template/core/connectivity/connectivity_state.dart';

/// Sets up a mock ConnectivityBloc in online state
MockConnectivityBloc createMockConnectivityBloc({
  ConnectivityState initialState = const ConnectivityState.online(),
  Stream<ConnectivityState>? stream,
}) {
  final bloc = MockConnectivityBloc();
  when(() => bloc.state).thenReturn(initialState);
  when(() => bloc.stream).thenAnswer((_) => stream ?? const Stream.empty());
  return bloc;
}

/// Common test setup that should run in setUpAll
void setupTestDependencies() {
  // Register fallback values for mocktail
  // Add more as needed for your models
}

/// Mock classes
class MockConnectivityBloc extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}
```

### 3. `test/helpers/mock_providers.dart`
Reusable mock implementations:
```dart
import 'package:mocktail/mocktail.dart';
import 'package:flutter_template/core/network/dio_client.dart';
import 'package:flutter_template/core/network/offline_queue.dart';

class MockDioClient extends Mock implements DioClient {}

class MockOfflineQueue extends Mock implements OfflineQueue {}

// Add more mock classes as needed
```

### 4. `test/helpers/widget_test_helpers.dart`
Widget test utilities:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Wraps a widget with necessary providers for testing
Widget createTestableWidget(
  Widget child, {
  List<BlocProvider> blocProviders = const [],
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: blocProviders,
      child: Scaffold(body: child),
    ),
  );
}

/// Pumps widget and waits for animations to settle
extension WidgetTesterExtensions on WidgetTester {
  Future<void> pumpAndSettle2() async {
    await pumpAndSettle(const Duration(milliseconds: 100));
  }
}
```

### 5. `test/fixtures/api_responses.dart`
JSON fixtures for API response mocking:
```dart
/// Mock API responses for testing
class ApiFixtures {
  ApiFixtures._();

  static const itemsResponse = '''
  {
    "data": [
      {"id": "1", "title": "Item 1", "createdAt": "2024-01-01T00:00:00Z"},
      {"id": "2", "title": "Item 2", "createdAt": "2024-01-02T00:00:00Z"}
    ]
  }
  ''';

  static const errorResponse = '''
  {
    "error": "Something went wrong",
    "code": "INTERNAL_ERROR"
  }
  ''';

  static const emptyResponse = '''
  {
    "data": []
  }
  ''';
}
```

### 6. `test/factories/item_factory.dart`
Factory for creating test data:
```dart
import 'package:flutter_template/features/home/data/models/item.dart';

class ItemFactory {
  ItemFactory._();

  static int _counter = 0;

  /// Create a single test item with optional overrides
  static Item create({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isCompleted = false,
  }) {
    _counter++;
    return Item(
      id: id ?? 'test_item_$_counter',
      title: title ?? 'Test Item $_counter',
      description: description,
      createdAt: createdAt ?? DateTime(2024, 1, _counter),
      updatedAt: updatedAt,
      isCompleted: isCompleted,
    );
  }

  /// Create a list of test items
  static List<Item> createList(int count) {
    return List.generate(count, (_) => create());
  }

  /// Reset counter (call in setUp if needed)
  static void reset() {
    _counter = 0;
  }
}
```

### 7. `scripts/test/run-all.sh`
Run full test suite:
```bash
#!/bin/bash
set -e

echo "🧪 Running all tests..."

# Run tests with machine-readable output for CI
flutter test --reporter=expanded

echo "✅ All tests passed!"
```

### 8. `scripts/test/coverage.sh`
Generate coverage report:
```bash
#!/bin/bash
set -e

echo "📊 Running tests with coverage..."

# Run tests with coverage
flutter test --coverage

# Check if lcov is installed for HTML report
if command -v lcov &> /dev/null; then
    echo "📄 Generating HTML report..."

    # Remove generated files from coverage
    lcov --remove coverage/lcov.info \
        '*.freezed.dart' \
        '*.g.dart' \
        '*.gr.dart' \
        -o coverage/lcov.info

    # Generate HTML
    genhtml coverage/lcov.info -o coverage/html

    echo "✅ Coverage report: coverage/html/index.html"

    # Open report on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open coverage/html/index.html
    fi
else
    echo "⚠️  Install lcov for HTML reports: brew install lcov"
    echo "📄 Raw coverage data: coverage/lcov.info"
fi
```

### 9. `scripts/test/watch.sh`
Watch mode for TDD:
```bash
#!/bin/bash

echo "👀 Watching for changes..."
echo "Press Ctrl+C to stop"

# Use flutter test in watch mode if available, otherwise use entr
if command -v entr &> /dev/null; then
    find lib test -name '*.dart' | entr -c flutter test
else
    echo "⚠️  Install entr for watch mode: brew install entr"
    echo "Running tests once instead..."
    flutter test
fi
```

### 10. `.claude/commands/add-test.md`
```markdown
Generate tests for an existing file.

## Input Required
- Path to file to test (e.g., `lib/features/profile/presentation/bloc/profile_bloc.dart`)

## Process

1. Read the source file to understand its public API
2. Identify what should be tested:
   - For BLoC: all events and state transitions
   - For Repository: success/failure paths, offline handling
   - For Utils: all public methods
3. Create test file at mirror path under `test/`
4. Generate tests using appropriate patterns:
   - BLoC → `blocTest`
   - Repository → standard async tests
   - Widget → `testWidgets`
5. Include proper mocks and setup

## Test File Location
- `lib/features/foo/bar.dart` → `test/features/foo/bar_test.dart`
- `lib/core/utils/foo.dart` → `test/core/utils/foo_test.dart`

## After Generation
1. Run `flutter test path/to/test_file.dart` to verify
2. Review generated tests for completeness
3. Add edge cases as needed
```

### 11. `.claude/commands/run-tests.md`
```markdown
Run tests with coverage and report results.

## Actions
1. Run `flutter test --coverage`
2. Report pass/fail count
3. If coverage tool available, show coverage percentage
4. Highlight any failing tests

## Options
- Specific file: Run tests for one file
- All: Run full test suite
- Coverage: Include coverage report
```

### 12. `.claude/commands/fix-failing-tests.md`
```markdown
Analyze and fix failing tests.

## Process
1. Run `flutter test` to identify failures
2. For each failing test:
   - Read the test to understand expected behavior
   - Read the implementation to understand actual behavior
   - Determine if test or implementation is wrong
   - Fix the appropriate file
3. Re-run tests to confirm fix
4. Report what was fixed

## Rules
- If test expectation matches requirements, fix implementation
- If implementation is correct, fix test
- If unclear, ask before making changes
```

### 13. Update `Makefile`
Add test targets:
```makefile
# === Testing ===

test: ## Run all tests
	./scripts/test/run-all.sh

test-coverage: ## Run tests with coverage report
	./scripts/test/coverage.sh

test-watch: ## Run tests in watch mode (requires entr)
	./scripts/test/watch.sh

test-file: ## Run specific test file (use FILE=path/to/test.dart)
	flutter test $(FILE)
```

### 14. `.github/workflows/test.yml` (reference for CI)
Document CI workflow pattern (actual implementation in Issue #1):
```yaml
# Reference for CI setup - see Issue #1 for full implementation
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - name: Check coverage
        run: |
          # Fail if coverage below threshold
          # Implementation details in Issue #1
```

---

## What We're NOT Doing

- **No end-to-end test framework setup** — that's app-specific
- **No visual regression testing** — golden tests are optional, documented but not configured
- **No mutation testing** — overkill for template
- **No test database setup** — repositories use mocks

## Structure After Implementation

```
flutter-project-template/
├── test/
│   ├── helpers/
│   │   ├── test_helpers.dart
│   │   ├── mock_providers.dart
│   │   └── widget_test_helpers.dart
│   ├── fixtures/
│   │   └── api_responses.dart
│   ├── factories/
│   │   └── item_factory.dart
│   ├── core/
│   │   └── utils/
│   │       └── result_test.dart        # Existing
│   ├── features/
│   │   └── home/
│   │       └── presentation/
│   │           └── bloc/
│   │               └── home_bloc_test.dart  # Existing
│   └── shared/
│       └── widgets/
│           └── error_view_test.dart    # Existing
├── scripts/
│   └── test/
│       ├── run-all.sh
│       ├── coverage.sh
│       └── watch.sh
├── docs/
│   └── testing.md
├── .claude/
│   └── commands/
│       ├── add-test.md
│       ├── run-tests.md
│       └── fix-failing-tests.md
└── Makefile                            # Updated
```

## Estimated Work

~14 files. Mix of documentation, test utilities, and scripts. The test helpers and factories are small but high-value. One focused session.
