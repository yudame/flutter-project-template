# Plan: Localization (i18n) Documentation & Setup

## Goal

Add comprehensive localization support documentation and starter configuration so projects using this template can easily add multi-language support.

## Current State

- No i18n setup in the template
- No localization documentation
- `main.dart` has no localization delegates configured
- No ARB files or l10n configuration

## Approach

Use Flutter's official localization approach: **ARB files + flutter_localizations + gen-l10n**. This is the recommended pattern and integrates well with the existing architecture.

We'll provide:
1. Documentation explaining the patterns and conventions
2. Configuration files ready to use
3. Example ARB files with common strings
4. Shell scripts for translation workflow
5. Claude commands for adding translations

---

## Files to Create

### 1. `docs/localization.md`
Comprehensive documentation covering:
- Flutter i18n overview (why ARB + gen-l10n over intl package alone)
- Project structure for translations
- String key naming conventions (snake_case, descriptive)
- Placeholders: `Hello, {name}!`
- Pluralization: `{count, plural, =0{No items} =1{1 item} other{{count} items}}`
- Select (gender): `{gender, select, male{He} female{She} other{They}}`
- RTL language considerations
- Date/number/currency formatting with `intl` package
- Translation workflow (adding strings, working with translators)
- Common tools (Crowdin, Lokalise, POEditor)

### 2. `l10n.yaml`
Configuration file for gen-l10n:
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/l10n/generated
nullable-getter: false
```

### 3. `lib/l10n/app_en.arb`
English source strings (template for common patterns):
```json
{
  "@@locale": "en",
  "appTitle": "My App",
  "@appTitle": { "description": "The application title" },
  "welcomeMessage": "Welcome, {name}!",
  "@welcomeMessage": {
    "placeholders": { "name": { "type": "String" } }
  },
  "itemCount": "{count, plural, =0{No items} =1{1 item} other{{count} items}}",
  "@itemCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "errorGeneric": "Something went wrong. Please try again.",
  "buttonRetry": "Retry",
  "buttonCancel": "Cancel",
  "buttonSave": "Save",
  "loadingMessage": "Loading..."
}
```

### 4. `lib/l10n/app_es.arb`
Spanish example (shows translation pattern):
```json
{
  "@@locale": "es",
  "appTitle": "Mi App",
  "welcomeMessage": "¡Bienvenido, {name}!",
  "itemCount": "{count, plural, =0{Sin elementos} =1{1 elemento} other{{count} elementos}}",
  "errorGeneric": "Algo salió mal. Por favor, inténtalo de nuevo.",
  "buttonRetry": "Reintentar",
  "buttonCancel": "Cancelar",
  "buttonSave": "Guardar",
  "loadingMessage": "Cargando..."
}
```

### 5. Update `pubspec.yaml`
Add to flutter section:
```yaml
flutter:
  generate: true
```

Ensure dependencies include:
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any
```

### 6. Update `lib/main.dart`
Add localization delegates to MaterialApp:
```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';

MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  // ...
)
```

### 7. `scripts/l10n/check-missing.sh`
Script to find untranslated strings:
```bash
#!/bin/bash
# Compares ARB files against the source (English) to find missing keys
SOURCE="lib/l10n/app_en.arb"
for file in lib/l10n/app_*.arb; do
  if [ "$file" != "$SOURCE" ]; then
    echo "Checking $file..."
    # Compare keys (excluding @-prefixed metadata)
    diff <(jq -r 'keys[]' "$SOURCE" | grep -v '^@' | sort) \
         <(jq -r 'keys[]' "$file" | grep -v '^@' | sort) \
      | grep '^<' | sed 's/< /Missing: /'
  fi
done
```

### 8. `scripts/l10n/sort-arb.sh`
Script to sort ARB keys alphabetically (keeps files consistent):
```bash
#!/bin/bash
# Sorts ARB file keys alphabetically while keeping metadata with their keys
for file in lib/l10n/app_*.arb; do
  echo "Sorting $file..."
  jq -S '.' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
done
```

### 9. `.claude/commands/add-translation.md`
Claude command to add a new translatable string:
```markdown
Add a new translatable string to the app.

1. Ask for: key name, English text, description, any placeholders
2. Add to `lib/l10n/app_en.arb` with proper metadata
3. Run `flutter gen-l10n` to regenerate
4. Show usage example: `AppLocalizations.of(context)!.keyName`
5. Remind to add translations to other ARB files
```

### 10. `.claude/commands/add-locale.md`
Claude command to add support for a new language:
```markdown
Add support for a new language/locale.

1. Ask for: locale code (e.g., 'fr', 'de', 'ja')
2. Create `lib/l10n/app_{locale}.arb` copying structure from app_en.arb
3. Mark all strings as needing translation (or provide translations if known)
4. Run `flutter gen-l10n`
5. Verify new locale appears in supportedLocales
```

### 11. Update `Makefile`
Add l10n targets:
```makefile
l10n: ## Generate localization files
	flutter gen-l10n

l10n-check: ## Check for missing translations
	./scripts/l10n/check-missing.sh

l10n-sort: ## Sort ARB files alphabetically
	./scripts/l10n/sort-arb.sh
```

---

## What We're NOT Doing

- **No runtime language switching UI** — that's app-specific
- **No translation service integration** — just document the tools
- **No automatic translation** — human translations are app responsibility
- **No complex pluralization rules** — just document the pattern

## Structure After Implementation

```
flutter-project-template/
├── l10n.yaml                          # gen-l10n configuration
├── lib/
│   ├── l10n/
│   │   ├── app_en.arb                 # English source
│   │   ├── app_es.arb                 # Spanish example
│   │   └── generated/                 # (gitignored, generated)
│   │       └── app_localizations.dart
│   └── main.dart                      # Updated with delegates
├── scripts/
│   └── l10n/
│       ├── check-missing.sh
│       └── sort-arb.sh
├── docs/
│   └── localization.md
└── .claude/
    └── commands/
        ├── add-translation.md
        └── add-locale.md
```

## Estimated Work

~12 files. Mostly configuration and documentation. One focused session.
