# Template Setup Checklist

After creating a new repository from this template, follow these steps:

## 1. Rename the Package

- [ ] Update `name` in `pubspec.yaml` (e.g., `name: my_app`)
- [ ] Search and replace `flutter_template` with your package name in all imports
- [ ] Update `package:flutter_template/` to `package:my_app/` throughout the codebase

## 2. Configure App Identity

### iOS (`ios/Runner/Info.plist`)
- [ ] Update `CFBundleDisplayName` - App name shown to users
- [ ] Update `CFBundleIdentifier` - Bundle ID (e.g., `com.yourcompany.myapp`)
- [ ] Update `CFBundleName` - Short app name

### Android (`android/app/build.gradle`)
- [ ] Update `applicationId` in `defaultConfig` (e.g., `com.yourcompany.myapp`)
- [ ] Update `namespace` to match

### Android (`android/app/src/main/AndroidManifest.xml`)
- [ ] Update `android:label` - App name shown to users

## 3. Set Up Environment

```bash
cp .env.example .env
```

Edit `.env` with your values:
- [ ] `API_BASE_URL` - Your backend API URL
- [ ] `SENTRY_DSN` - Sentry error tracking (optional)
- [ ] `ENVIRONMENT` - `development`, `staging`, or `production`

## 4. Firebase Setup (if using)

1. Create a Firebase project at https://console.firebase.google.com
2. Add Android app:
   - [ ] Download `google-services.json`
   - [ ] Place in `android/app/`
3. Add iOS app:
   - [ ] Download `GoogleService-Info.plist`
   - [ ] Place in `ios/Runner/`

## 5. Run Initial Setup

```bash
make setup
```

This will:
- Install dependencies (`flutter pub get`)
- Run code generation (Freezed, JSON serializable)
- Generate localization files

## 6. Verify Everything Works

```bash
make test    # Run all tests
make run     # Start the app
```

## 7. Clean Up Template Files

Consider removing or updating:
- [ ] This file (`.github/TEMPLATE_SETUP.md`)
- [ ] `docs/plans/` - Implementation plans for template features
- [ ] Example feature (`lib/features/home/`) if not needed

## 8. Update Documentation

- [ ] Update `README.md` with your project description
- [ ] Update `CLAUDE.md` with project-specific instructions
- [ ] Add your team's conventions to documentation

## Quick Reference

| Task | Command |
|------|---------|
| Install dependencies | `make setup` |
| Run tests | `make test` |
| Run app | `make run` |
| Generate code | `make gen` |
| Generate translations | `make l10n` |
| Format code | `make format` |
| Analyze code | `make analyze` |

## Getting Help

- Architecture documentation: `docs/architecture.md`
- Implementation patterns: `docs/implemented.md`
- Testing guide: `docs/testing.md`
- Localization guide: `docs/localization.md`
