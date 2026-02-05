Create a reusable widget.

## Input Required

Ask for:
- **Widget name** (PascalCase, e.g., "UserAvatar", "StatusBadge", "PriceTag")
- **Props/parameters** needed
- **Location**: feature-specific or shared
- **Whether to create a test file**

## Template

### StatelessWidget (most common)

```dart
import 'package:flutter/material.dart';

/// {Description of what the widget does}
class {WidgetName} extends StatelessWidget {
  /// {Description of prop}
  final String title;

  /// {Description of prop}
  final VoidCallback? onTap;

  const {WidgetName}({
    super.key,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}
```

### StatefulWidget (when internal state is needed)

```dart
import 'package:flutter/material.dart';

/// {Description of what the widget does}
class {WidgetName} extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String>? onChanged;

  const {WidgetName}({
    super.key,
    required this.initialValue,
    this.onChanged,
  });

  @override
  State<{WidgetName}> createState() => _{WidgetName}State();
}

class _{WidgetName}State extends State<{WidgetName}> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return // TODO: Implement
  }
}
```

## Location Rules

| Type | Location |
|------|----------|
| Feature-specific | `lib/features/{feature}/presentation/widgets/` |
| Shared/reusable | `lib/shared/widgets/` |

## Test Template (if requested)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/{path_to_widget}.dart';

void main() {
  group('{WidgetName}', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: {WidgetName}(
              title: 'Test',
            ),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: {WidgetName}(
              title: 'Test',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType({WidgetName}));
      expect(tapped, isTrue);
    });
  });
}
```

## Widget Best Practices

1. **Use `const` constructors** when possible
2. **Accept callbacks** instead of implementing behavior (`onTap`, `onChanged`)
3. **Use theme colors** from `Theme.of(context)` instead of hardcoded colors
4. **Document public API** with `///` comments
5. **Keep widgets focused** - one responsibility per widget
6. **Use composition** - build complex widgets from simple ones

## After Generation

1. Import where needed:
   ```dart
   import 'package:flutter_template/shared/widgets/{name}.dart';
   ```

2. Consider adding to a widget catalog if it's a shared component
