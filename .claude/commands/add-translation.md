Add a new translatable string to the app.

## Process

1. **Gather information:**
   - Key name (camelCase, e.g., `welcomeTitle`, `errorInvalidEmail`)
   - English text
   - Description for translators
   - Any placeholders needed (name, count, date, etc.)

2. **Add to English ARB file** (`lib/l10n/app_en.arb`):
   ```json
   {
     "keyName": "The English text with {placeholder}",
     "@keyName": {
       "description": "Context for translators",
       "placeholders": {
         "placeholder": {
           "type": "String",
           "example": "example value"
         }
       }
     }
   }
   ```

3. **Regenerate localizations:**
   ```bash
   flutter gen-l10n
   ```

4. **Show usage example:**
   ```dart
   // Simple string
   AppLocalizations.of(context)!.keyName

   // With placeholder
   AppLocalizations.of(context)!.keyName('value')
   ```

5. **Remind about other locales:**
   - Add the translation to `app_es.arb` and other locale files
   - Run `./scripts/l10n/check-missing.sh` to verify

## Naming Conventions

| Pattern | Example | Use For |
|---------|---------|---------|
| `{screen}Title` | `homeTitle` | Screen titles |
| `{screen}Subtitle` | `homeSubtitle` | Screen subtitles |
| `button{Action}` | `buttonSave` | Button labels |
| `label{Field}` | `labelEmail` | Form labels |
| `hint{Field}` | `hintEmail` | Input hints |
| `error{Type}` | `errorRequired` | Validation errors |
| `{feature}Message` | `loadingMessage` | Status messages |

## Placeholder Types

- `String` - Text values
- `int` - Whole numbers (use with plural)
- `double` - Decimal numbers
- `DateTime` - Dates (can specify format)
- `num` - Generic numbers
