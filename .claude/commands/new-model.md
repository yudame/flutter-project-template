Create a new Freezed model with JSON serialization.

## Input Required

Ask for:
- **Model name** (PascalCase, e.g., "UserProfile", "Order", "Product")
- **Fields** (name and type for each)
- **Location** (which feature, or `shared` for cross-feature models)

## Template

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '{snake_name}.freezed.dart';
part '{snake_name}.g.dart';

@freezed
abstract class {ModelName} with _${ModelName} {
  const factory {ModelName}({
    required String id,
    // Add provided fields here
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _{ModelName};

  factory {ModelName}.fromJson(Map<String, dynamic> json) =>
      _${ModelName}FromJson(json);
}
```

## Field Type Guidelines

| Dart Type | JSON Type | Notes |
|-----------|-----------|-------|
| `String` | `string` | |
| `int` | `number` | |
| `double` | `number` | |
| `bool` | `boolean` | |
| `DateTime` | `string` | ISO 8601 format |
| `List<T>` | `array` | |
| `Map<String, T>` | `object` | |
| Custom model | `object` | Needs its own Freezed class |

## Optional vs Required

- Use `required` for fields that must always be present
- Use nullable (`Type?`) for optional fields
- Use `@Default(value)` for optional fields with default values

Example:
```dart
const factory User({
  required String id,           // Always required
  required String email,        // Always required
  String? phoneNumber,          // Optional, can be null
  @Default(false) bool isAdmin, // Optional with default
}) = _User;
```

## Location

- Feature-specific: `lib/features/{feature}/data/models/`
- Shared: `lib/shared/models/`

## After Generation

1. Run code generation:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

2. Import where needed:
   ```dart
   import 'package:flutter_template/features/{feature}/data/models/{name}.dart';
   ```

3. Add factory to `test/factories/` if the model will be used in tests
