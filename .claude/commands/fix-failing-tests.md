Analyze and fix failing tests.

## Process

1. **Run tests** to identify failures:
   ```bash
   flutter test
   ```

2. **For each failing test**:
   - Read the test to understand expected behavior
   - Read the implementation to understand actual behavior
   - Determine if the test or implementation is wrong
   - Fix the appropriate file

3. **Re-run tests** to confirm the fix

4. **Report** what was fixed

## Decision Rules

### Fix the Implementation When:
- Test expectation matches documented requirements
- Test was passing before recent code changes
- Multiple tests fail in a pattern suggesting implementation bug

### Fix the Test When:
- Implementation behavior is intentional and correct
- Test has outdated expectations after a feature change
- Test is testing implementation details instead of behavior

### Ask for Clarification When:
- Requirements are ambiguous
- Both test and implementation could be correct
- Change would affect other parts of the system

## Common Fixes

### Mock Not Set Up
```dart
// Error: "No stub registered for method"
// Fix: Add mock setup in setUp() or build()
when(() => mockRepo.getData()).thenAnswer((_) async => Result.success(data));
```

### Missing Fallback Value
```dart
// Error: "No matching calls"
// Fix: Register fallback value in setUpAll
setUpAll(() {
  registerFallbackValue(FakeItem());
});
```

### Async Not Awaited
```dart
// Error: Test passes but state not updated
// Fix: Add wait parameter to blocTest
blocTest<MyBloc, MyState>(
  'async operation',
  wait: const Duration(milliseconds: 100),
  // ...
);
```

### State Comparison Fails
```dart
// Error: States don't match even though they look the same
// Fix: Ensure Freezed models are properly generated
// Run: flutter pub run build_runner build --delete-conflicting-outputs
```

## Report Format

After fixing, report:
1. Which tests were failing
2. Root cause of each failure
3. What was changed to fix it
4. Confirmation tests now pass
