Run tests and report results.

## Options

1. **All tests**: Run the complete test suite
2. **Specific file**: Run tests for one file
3. **With coverage**: Include coverage report

## Process

### Run All Tests
```bash
flutter test
```

### Run Specific File
```bash
flutter test test/path/to/file_test.dart
```

### Run With Coverage
```bash
flutter test --coverage
```

## Report Format

After running tests, report:
1. Total tests run
2. Passed / Failed count
3. Any failing test names and error messages
4. Coverage percentage (if coverage was run)

## Handling Failures

If tests fail:
1. Show the failing test name
2. Show the expected vs actual values
3. Suggest potential fixes based on the error

## Example Output

```
🧪 Running tests...

✅ 23 tests passed
❌ 2 tests failed

Failed tests:
1. HomeBloc emits [loading, error] when load fails
   Expected: [HomeState.loading(), HomeState.error('Network error')]
   Actual: [HomeState.loading()]

2. ItemRepository returns cached data when offline
   Expected: Result.success([item1, item2])
   Actual: Result.failure('No cached data')

Coverage: 78.5% (target: 80%)
```
