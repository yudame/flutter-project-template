Generate tests for an existing Dart file.

## Input Required
- Path to the file to test (e.g., `lib/features/profile/presentation/bloc/profile_bloc.dart`)

## Process

1. **Read the source file** to understand its public API
2. **Identify what should be tested** based on file type:
   - **BLoC**: All events and their resulting state transitions
   - **Repository**: Success/failure paths, offline handling, caching behavior
   - **Utils**: All public methods with various inputs
   - **Widget**: User interactions, state rendering
3. **Create test file** at mirror path under `test/`
4. **Generate tests** using appropriate patterns from `docs/testing.md`
5. **Include proper setup**: mocks, factories, fallback values

## Test File Location

Mirror the `lib/` structure under `test/`:
- `lib/features/foo/bar.dart` → `test/features/foo/bar_test.dart`
- `lib/core/utils/foo.dart` → `test/core/utils/foo_test.dart`

## Test Structure Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// For BLoC tests:
import 'package:bloc_test/bloc_test.dart';

// Import the file being tested
// Import test helpers, factories, mocks

void main() {
  // For classes with mocked dependencies
  late MockDependency mockDep;

  setUpAll(() {
    // Register fallback values for any() matchers
  });

  setUp(() {
    // Create fresh mocks for each test
    mockDep = MockDependency();
  });

  group('ClassName', () {
    test('description of behavior', () {
      // Arrange
      // Act
      // Assert
    });

    // For BLoCs use blocTest
    blocTest<MyBloc, MyState>(
      'emits expected states',
      build: () => MyBloc(dep: mockDep),
      act: (bloc) => bloc.add(Event()),
      expect: () => [ExpectedState()],
    );
  });
}
```

## After Generation

1. Run `flutter test path/to/test_file.dart` to verify tests pass
2. Review generated tests for completeness
3. Add edge cases and error scenarios as needed
4. Run `make test-coverage` to check coverage impact
