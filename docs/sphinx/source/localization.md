# Localization (i18n)

This guide covers internationalization patterns for Flutter apps using this template.

## Overview

We use Flutter's official localization approach:
- **ARB files** (Application Resource Bundle) for translation strings
- **flutter_localizations** for Material/Cupertino widget translations
- **gen-l10n** for code generation

This approach is recommended by the Flutter team and provides:
- Type-safe access to translations
- Compile-time checking for missing translations
- Support for pluralization, gender, and placeholders
- IDE autocomplete for translation keys

## Project Structure

```
lib/
├── l10n/
│   ├── app_en.arb              # English (source language)
│   ├── app_es.arb              # Spanish
│   ├── app_fr.arb              # French
│   └── generated/              # Auto-generated (gitignored)
│       └── app_localizations.dart
└── main.dart                   # Configured with delegates
```

## Configuration

### l10n.yaml

The `l10n.yaml` file in the project root configures code generation:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/l10n/generated
nullable-getter: false
```

### pubspec.yaml

Ensure these are configured:

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true
```

## ARB File Format

ARB files are JSON with metadata. The English file (`app_en.arb`) is the source of truth.

### Basic Strings

```json
{
  "@@locale": "en",
  "appTitle": "My App",
  "@appTitle": {
    "description": "The title shown in the app bar"
  }
}
```

### Placeholders

```json
{
  "welcomeMessage": "Welcome, {name}!",
  "@welcomeMessage": {
    "description": "Greeting shown after login",
    "placeholders": {
      "name": {
        "type": "String",
        "example": "John"
      }
    }
  }
}
```

Usage: `AppLocalizations.of(context)!.welcomeMessage('John')`

### Pluralization

```json
{
  "itemCount": "{count, plural, =0{No items} =1{1 item} other{{count} items}}",
  "@itemCount": {
    "description": "Shows the number of items",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

Usage: `AppLocalizations.of(context)!.itemCount(5)` → "5 items"

### Select (Gender/Category)

```json
{
  "userGreeting": "{gender, select, male{He is online} female{She is online} other{They are online}}",
  "@userGreeting": {
    "placeholders": {
      "gender": {
        "type": "String"
      }
    }
  }
}
```

### Numbers and Dates

```json
{
  "priceLabel": "Price: {price}",
  "@priceLabel": {
    "placeholders": {
      "price": {
        "type": "double",
        "format": "currency",
        "optionalParameters": {
          "symbol": "$",
          "decimalDigits": 2
        }
      }
    }
  },
  "lastUpdated": "Updated: {date}",
  "@lastUpdated": {
    "placeholders": {
      "date": {
        "type": "DateTime",
        "format": "yMMMd"
      }
    }
  }
}
```

## Usage in Code

### Accessing Translations

```dart
import 'package:flutter_template/l10n/generated/app_localizations.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(l10n.appTitle),
        Text(l10n.welcomeMessage('John')),
        Text(l10n.itemCount(5)),
      ],
    );
  }
}
```

### Extension for Cleaner Access (Optional)

```dart
extension BuildContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

// Usage
Text(context.l10n.appTitle)
```

## Naming Conventions

### Key Names

Use `camelCase` with descriptive names:

| Pattern | Example | Description |
|---------|---------|-------------|
| `{screen}{element}` | `homeTitle`, `loginButton` | Screen-specific strings |
| `{action}Message` | `errorMessage`, `successMessage` | Status messages |
| `button{Action}` | `buttonSave`, `buttonCancel` | Button labels |
| `label{Field}` | `labelEmail`, `labelPassword` | Form field labels |
| `hint{Field}` | `hintEmail`, `hintPassword` | Input hints |
| `error{Type}` | `errorRequired`, `errorInvalidEmail` | Validation errors |

### Descriptions

Always include `@key` metadata with descriptions. This helps translators understand context:

```json
{
  "deleteConfirmation": "Are you sure you want to delete this?",
  "@deleteConfirmation": {
    "description": "Shown in confirmation dialog when user tries to delete an item"
  }
}
```

## Adding New Translations

### 1. Add to English ARB

```json
{
  "newFeatureTitle": "New Feature",
  "@newFeatureTitle": {
    "description": "Title for the new feature screen"
  }
}
```

### 2. Regenerate

```bash
make l10n
# or
flutter gen-l10n
```

### 3. Use in Code

```dart
Text(AppLocalizations.of(context)!.newFeatureTitle)
```

### 4. Add to Other Languages

Update each `app_*.arb` file with the translation.

## Adding a New Language

1. Create `lib/l10n/app_{locale}.arb` (e.g., `app_fr.arb` for French)
2. Copy structure from `app_en.arb`
3. Translate all strings
4. Run `flutter gen-l10n`
5. The new locale is automatically available

## Right-to-Left (RTL) Languages

Flutter handles RTL automatically when you add RTL locales (Arabic, Hebrew, etc.).

For custom layouts that need RTL awareness:

```dart
final isRtl = Directionality.of(context) == TextDirection.rtl;

// Or use directional widgets
Padding(
  padding: EdgeInsetsDirectional.only(start: 16),
  child: Text('Aligned to start'),
)
```

## Date, Number, and Currency Formatting

Use the `intl` package for locale-aware formatting:

```dart
import 'package:intl/intl.dart';

// Get current locale
final locale = Localizations.localeOf(context).toString();

// Format date
final dateFormat = DateFormat.yMMMd(locale);
final formattedDate = dateFormat.format(DateTime.now());

// Format currency
final currencyFormat = NumberFormat.currency(locale: locale, symbol: '\$');
final formattedPrice = currencyFormat.format(19.99);

// Format number
final numberFormat = NumberFormat.decimalPattern(locale);
final formattedNumber = numberFormat.format(1234567);
```

## Translation Workflow

### For Development

1. Add strings to `app_en.arb` as you build features
2. Run `make l10n` to regenerate
3. Use type-safe accessors in code
4. Before release, export ARB files to translators

### For Translators

**Option 1: Direct ARB Editing**
- Share ARB files directly
- Translators edit JSON (simple but error-prone)

**Option 2: Translation Management Platforms**
- [Crowdin](https://crowdin.com/) - Popular, good Flutter support
- [Lokalise](https://lokalise.com/) - Developer-focused
- [POEditor](https://poeditor.com/) - Simple and affordable
- [Phrase](https://phrase.com/) - Enterprise features

These platforms:
- Import/export ARB files
- Provide translator-friendly UI
- Track translation progress
- Support translation memory

### CI/CD Integration

Check for missing translations in CI:

```bash
# scripts/l10n/check-missing.sh
./scripts/l10n/check-missing.sh
```

This compares all ARB files against the English source and reports missing keys.

## Common Patterns

### Error Messages with Details

```json
{
  "errorNetwork": "Network error. Please check your connection.",
  "errorServerCode": "Server error (code: {code})",
  "@errorServerCode": {
    "placeholders": {
      "code": {"type": "int"}
    }
  }
}
```

### Time-Relative Strings

```json
{
  "timeAgo": "{time} ago",
  "timeJustNow": "Just now",
  "timeMinutes": "{count, plural, =1{1 minute} other{{count} minutes}}",
  "timeHours": "{count, plural, =1{1 hour} other{{count} hours}}",
  "timeDays": "{count, plural, =1{1 day} other{{count} days}}"
}
```

### Empty States

```json
{
  "emptyListTitle": "No items yet",
  "emptyListSubtitle": "Add your first item to get started",
  "emptySearchTitle": "No results found",
  "emptySearchSubtitle": "Try a different search term"
}
```

## Testing

### Widget Tests with Localization

```dart
testWidgets('displays localized title', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: MyWidget(),
    ),
  );

  expect(find.text('My App'), findsOneWidget);
});
```

### Testing Multiple Locales

```dart
for (final locale in ['en', 'es', 'fr']) {
  testWidgets('renders correctly in $locale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(locale),
        home: MyWidget(),
      ),
    );

    // Verify no overflow or layout issues
    expect(tester.takeException(), isNull);
  });
}
```

## Troubleshooting

### "AppLocalizations.of(context) returns null"

Ensure your widget is below `MaterialApp` in the widget tree and localization delegates are configured.

### Changes Not Reflecting

Run `flutter gen-l10n` or `make l10n` after modifying ARB files.

### Pluralization Not Working

Check the ICU message syntax. Common mistakes:
- Missing `other` case (required)
- Wrong brace matching
- Incorrect placeholder type

### IDE Not Finding Generated File

The file is at `lib/l10n/generated/app_localizations.dart`. Run code generation and restart IDE.

## Make Commands

```bash
make l10n        # Generate localization files
make l10n-check  # Check for missing translations
make l10n-sort   # Sort ARB files alphabetically
```
