Add support for a new language/locale.

## Process

1. **Get locale code:**
   - Ask for the locale code (e.g., `fr` for French, `de` for German, `ja` for Japanese)
   - For regional variants, use full code (e.g., `pt_BR` for Brazilian Portuguese)

2. **Create the ARB file:**
   - Copy structure from `lib/l10n/app_en.arb`
   - Create `lib/l10n/app_{locale}.arb`
   - Set `"@@locale": "{locale}"` at the top
   - Remove all `@key` metadata entries (they're only needed in source)

3. **Translate strings:**
   - If translations are known, add them
   - If not, keep English as placeholder and mark for translation

4. **Regenerate localizations:**
   ```bash
   flutter gen-l10n
   ```

5. **Verify:**
   - Check that new locale appears in `AppLocalizations.supportedLocales`
   - Run app and test locale switching

## Example: Adding French

1. Create `lib/l10n/app_fr.arb`:
   ```json
   {
     "@@locale": "fr",
     "appTitle": "Mon App",
     "welcomeMessage": "Bienvenue, {name}!",
     "itemCount": "{count, plural, =0{Aucun élément} =1{1 élément} other{{count} éléments}}",
     "errorGeneric": "Une erreur s'est produite. Veuillez réessayer.",
     "buttonRetry": "Réessayer",
     "buttonCancel": "Annuler",
     "buttonSave": "Enregistrer",
     "loadingMessage": "Chargement..."
   }
   ```

2. Run `flutter gen-l10n`

3. Test in app:
   ```dart
   // Force French locale for testing
   MaterialApp(
     locale: const Locale('fr'),
     // ...
   )
   ```

## Common Locale Codes

| Code | Language |
|------|----------|
| `en` | English |
| `es` | Spanish |
| `fr` | French |
| `de` | German |
| `it` | Italian |
| `pt` | Portuguese |
| `pt_BR` | Brazilian Portuguese |
| `zh` | Chinese (Simplified) |
| `zh_TW` | Chinese (Traditional) |
| `ja` | Japanese |
| `ko` | Korean |
| `ar` | Arabic (RTL) |
| `he` | Hebrew (RTL) |
| `ru` | Russian |
| `hi` | Hindi |

## RTL Languages

Arabic (`ar`) and Hebrew (`he`) are right-to-left. Flutter handles this automatically, but test thoroughly:
- Text alignment
- Icon directions
- Layout flow
