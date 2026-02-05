# Testing Guide

This guide covers testing patterns and conventions for Flutter apps using this template.

## Philosophy

**Test behavior, not implementation.** Focus testing effort where it provides the most value:

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

## Test File Organization

```
test/
├── helpers/                    # Shared test utilities
│   ├── test_helpers.dart       # Common setup functions
│   ├── mock_providers.dart     # Reusable mock classes
│   └── widget_test_helpers.dart # Widget test utilities
├── fixtures/                   # Static test data
│   └── api_responses.dart      # Mock API responses
├── factories/                  # Dynamic test data generators
│   └── item_factory.dart       # Item model factory
├── core/                       # Tests for lib/core/
│   └── utils/
│       └── result_test.dart
├── features/                   # Tests for lib/features/
│   └── home/
│       └── presentation/
│           └── bloc/
│               └── home_bloc_test.dart
└── shared/                     # Tests for lib/shared/
    └── widgets/
        └── error_view_test.dart
```

## Patterns

### BLoC Testing with bloc_test

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMyRepository extends Mock implements MyRepository {}

void main() {
  late MockMyRepository mockRepo;

  setUp(() {
    mockRepo = MockMyRepository();
  });

  blocTest<MyBloc, MyState>(
    'emits [loading, loaded] when load succeeds',
    build: () {
      when(() => mockRepo.getData())
          .thenAnswer((_) async => Result.success(data));
      return MyBloc(repository: mockRepo);
    },
    act: (bloc) => bloc.add(const MyEvent.load()),
    expect: () => [
      const MyState.loading(),
      MyState.loaded(data),
    ],
    verify: (_) {
      verify(() => mockRepo.getData()).called(1);
    },
  );

  blocTest<MyBloc, MyState>(
    'emits [loading, error] when load fails',
    build: () {
      when(() => mockRepo.getData())
          .thenAnswer((_) async => const Result.failure('Error'));
      return MyBloc(repository: mockRepo);
    },
    act: (bloc) => bloc.add(const MyEvent.load()),
    expect: () => [
      const MyState.loading(),
      const MyState.error('Error'),
    ],
  );

  // Test with initial state
  blocTest<MyBloc, MyState>(
    'keeps current data when refresh fails',
    build: () {
      when(() => mockRepo.getData())
          .thenAnswer((_) async => const Result.failure('Error'));
      return MyBloc(repository: mockRepo);
    },
    seed: () => MyState.loaded(existingData),  // Set initial state
    act: (bloc) => bloc.add(const MyEvent.refresh()),
    expect: () => [],  // No state change expected
  );
}
```

### Mocking with mocktail

```dart
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';

// Mock a simple class
class MockMyRepository extends Mock implements MyRepository {}

// Mock a BLoC
class MockConnectivityBloc extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

// Fake for fallback values (needed for any() matchers)
class FakeItem extends Fake implements Item {}

void main() {
  setUpAll(() {
    // Register fallback values for any() matchers
    registerFallbackValue(FakeItem());
  });

  late MockMyRepository mockRepo;
  late MockConnectivityBloc mockConnectivity;

  setUp(() {
    mockRepo = MockMyRepository();
    mockConnectivity = MockConnectivityBloc();

    // Set up default behavior
    when(() => mockConnectivity.state).thenReturn(
      const ConnectivityState.online(),
    );
    when(() => mockConnectivity.stream).thenAnswer(
      (_) => const Stream.empty(),
    );
  });
}
```

### Test Data Factories

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
    bool isCompleted = false,
  }) {
    _counter++;
    return Item(
      id: id ?? 'test_item_$_counter',
      title: title ?? 'Test Item $_counter',
      description: description,
      createdAt: createdAt ?? DateTime(2024, 1, _counter),
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

// Usage
final item = ItemFactory.create(title: 'Custom Title');
final items = ItemFactory.createList(5);
```

### Widget Testing

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  testWidgets('displays items when loaded', (tester) async {
    final mockBloc = MockHomeBloc();
    when(() => mockBloc.state).thenReturn(
      HomeState.loaded([ItemFactory.create()]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<HomeBloc>.value(
          value: mockBloc,
          child: const HomePage(),
        ),
      ),
    );

    expect(find.text('Test Item 1'), findsOneWidget);
  });

  testWidgets('shows loading indicator initially', (tester) async {
    final mockBloc = MockHomeBloc();
    when(() => mockBloc.state).thenReturn(const HomeState.loading());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<HomeBloc>.value(
          value: mockBloc,
          child: const HomePage(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('calls load event on button tap', (tester) async {
    final mockBloc = MockHomeBloc();
    when(() => mockBloc.state).thenReturn(const HomeState.error('Error'));

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<HomeBloc>.value(
          value: mockBloc,
          child: const HomePage(),
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => mockBloc.add(const HomeEvent.load())).called(1);
  });
}
```

### Widget Test Helpers

```dart
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

// Usage
await tester.pumpWidget(
  createTestableWidget(
    const MyWidget(),
    blocProviders: [
      BlocProvider<HomeBloc>.value(value: mockBloc),
    ],
  ),
);
```

## What NOT to Test

- **Generated code** (`*.freezed.dart`, `*.g.dart`) - Already tested by package authors
- **Third-party packages** - Not your responsibility
- **Trivial getters/setters** - No logic to test
- **Private methods** - Test through public API
- **UI layout** - Unless critical to UX (use golden tests if needed)

## Running Tests

```bash
make test           # Run all tests
make test-coverage  # Run with coverage report
make test-watch     # Watch mode for TDD (requires entr)
make test-file FILE=test/path/to/test.dart  # Run specific test
```

## Coverage Reports

Coverage reports are generated in the `coverage/` directory:
- `coverage/lcov.info` - Raw coverage data
- `coverage/html/` - HTML report

View coverage report:
```bash
make test-coverage
# Opens coverage/html/index.html automatically on macOS
```

### Coverage in CI

For CI integration, use `--coverage` flag and upload to Codecov or similar:

```yaml
- run: flutter test --coverage
- uses: codecov/codecov-action@v3
  with:
    files: coverage/lcov.info
```

## Common Patterns

### Testing Async Operations

```dart
blocTest<MyBloc, MyState>(
  'handles async operation',
  build: () {
    when(() => mockRepo.fetchData()).thenAnswer(
      (_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return Result.success(data);
      },
    );
    return MyBloc(repository: mockRepo);
  },
  act: (bloc) => bloc.add(const MyEvent.fetch()),
  wait: const Duration(milliseconds: 150),  // Wait for async to complete
  expect: () => [
    const MyState.loading(),
    MyState.loaded(data),
  ],
);
```

### Testing Stream Subscriptions

```dart
blocTest<MyBloc, MyState>(
  'responds to connectivity changes',
  build: () {
    when(() => mockConnectivity.stream).thenAnswer(
      (_) => Stream.value(const ConnectivityState.online()),
    );
    return MyBloc(connectivityBloc: mockConnectivity);
  },
  wait: const Duration(milliseconds: 100),
  verify: (_) {
    // Verify side effects from stream events
  },
);
```

### Testing Error Handling

```dart
blocTest<MyBloc, MyState>(
  'handles network timeout',
  build: () {
    when(() => mockRepo.getData()).thenThrow(
      TimeoutException('Request timed out'),
    );
    return MyBloc(repository: mockRepo);
  },
  act: (bloc) => bloc.add(const MyEvent.load()),
  expect: () => [
    const MyState.loading(),
    const MyState.error('Request timed out'),
  ],
);
```

## Troubleshooting

### "No matching calls" Error
Ensure mock is set up before the test runs (in `setUp` or `build`).

### State Not Emitting
- Check that `emit` is called in the BLoC
- Verify mock returns expected values
- Use `wait` parameter for async operations

### Widget Test Fails with Provider Error
Wrap widget with necessary providers using `createTestableWidget` helper.

### Coverage Missing Files
Ensure files are imported somewhere in the test suite. Unused code won't appear in coverage.

## Best Practices

1. **One assertion per test** - Makes failures clear
2. **Descriptive test names** - State what should happen
3. **Arrange-Act-Assert** - Clear test structure
4. **Don't test implementation** - Test behavior and outcomes
5. **Use factories** - Consistent, readable test data
6. **Reset state** - Clean up in `setUp`/`tearDown`
7. **Mock at boundaries** - Repository, not HTTP client
