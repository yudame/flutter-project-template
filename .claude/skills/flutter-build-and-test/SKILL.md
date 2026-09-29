---
name: flutter-build-and-test
description: Build, analyze, format, and execute unit, widget, and BLoC tests in Flutter projects adhering to Dart 3 best practices.
---

# Building & Testing Flutter Projects

This skill guides you through formatting, analyzing, compiling, and testing Flutter applications using modern Dart 3 features, BLoC test utilities, and mocktail.

## Table of Contents
1. [Core Verification Commands](#core-verification-commands)
2. [BLoC Unit Testing](#bloc-unit-testing)
3. [Repository & Cache Unit Testing](#repository--cache-unit-testing)
4. [Widget Testing](#widget-testing)
5. [Code Coverage & Quality Gates](#code-coverage--quality-gates)

---

## Core Verification Commands

Always run these verification steps prior to opening pull requests or committing changes:

```bash
# 1. Format all code
dart format .

# 2. Run static analysis (strict mode)
flutter analyze --fatal-infos

# 3. Execute all tests
flutter test

# 4. Execute tests with coverage
flutter test --coverage
```

---

## BLoC Unit Testing

When testing BLoCs built with Dart 3 sealed events and states, utilize `package:bloc_test` and `package:mocktail`.

### Pattern:
```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late MyBloc bloc;
  late MockRepository mockRepo;

  setUp(() {
    mockRepo = MockRepository();
    bloc = MyBloc(repository: mockRepo);
  });

  tearDown(() {
    bloc.close();
  });

  group('MyBloc', () {
    test('initial state is correct', () {
      expect(bloc.state, equals(const MyState.initial()));
    });

    blocTest<MyBloc, MyState>(
      'emits [loading, loaded] when data loads successfully',
      build: () {
        when(() => mockRepo.fetchData())
            .thenAnswer((_) async => Result.success(mockData));
        return bloc;
      },
      act: (bloc) => bloc.add(const MyEvent.load()),
      expect: () => [
        const MyState.loading(),
        MyState.loaded(mockData),
      ],
      verify: (_) {
        verify(() => mockRepo.fetchData()).called(1);
      },
    );
  });
}
```

---

## Repository & Cache Unit Testing

Verify that repositories handle online, poor, and offline connectivity states, and correctly interact with `LocalCacheService`:

```dart
test('reads from cache when offline', () async {
  when(() => mockConnectivity.currentState)
      .thenReturn(const ConnectivityState.offline());
  when(() => mockLocalCache.getAll('items'))
      .thenAnswer((_) async => Result.success(cachedJsonList));

  final result = await repository.getItems();

  expect(result, isA<Success<List<Item>>>());
  verifyNever(() => mockDioClient.get(any()));
  verify(() => mockLocalCache.getAll('items')).called(1);
});
```

---

## Widget Testing

Widget tests verify user interaction, error views, and localized strings:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/shared/widgets/error_view.dart';

void main() {
  testWidgets('ErrorView displays message and triggers retry callback', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorView(
            message: 'Failed to load',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Failed to load'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retried, isTrue);
  });
}
```

---

## Code Coverage & Quality Gates

To generate and view an HTML coverage report:

```bash
# Generate lcov.info
flutter test --coverage

# Convert to HTML (requires lcov installed: brew install lcov)
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html
```
