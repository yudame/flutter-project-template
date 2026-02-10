# CI/CD Pipeline

This guide covers CI/CD conventions and GitHub Actions workflows for Flutter mobile app builds.

## Branch Strategy

| Branch | Purpose | Deploys To |
|--------|---------|------------|
| `main` | Production-ready code | Production |
| `develop` | Integration branch | Staging |
| `feature/*` | Work in progress | — |
| `release/*` | Release preparation | — |
| `hotfix/*` | Emergency fixes | — |

### Flow

```
feature/* ──► develop ──► release/* ──► main
                              │
                          hotfix/* ◄──┘
```

1. Create `feature/xyz` from `develop`
2. Open PR to `develop` when ready
3. Tests run automatically on PR
4. Squash merge after approval
5. Create `release/1.2.0` when ready to release
6. Final testing, then merge to `main`
7. Tag release on `main`

## PR Workflow

### Requirements

- All tests must pass
- Code analysis must pass (no warnings)
- Format check must pass
- At least one approval required

### Automated Checks

On every PR, the `flutter-test` workflow runs:
- `flutter analyze --fatal-infos`
- `dart format --set-exit-if-changed .`
- `flutter test --coverage`

## Version Numbering

Use semantic versioning: `MAJOR.MINOR.PATCH+BUILD`

| Component | When to Increment |
|-----------|-------------------|
| MAJOR | Breaking changes |
| MINOR | New features (backward compatible) |
| PATCH | Bug fixes |
| BUILD | Each build (auto-incremented in CI) |

### In pubspec.yaml

```yaml
version: 1.2.3+45
#        │ │ │  └── Build number (for stores)
#        │ │ └───── Patch
#        │ └─────── Minor
#        └───────── Major
```

### Git Tags

Tag releases as `v1.2.3`:

```bash
git tag v1.2.3
git push origin v1.2.3
```

## GitHub Actions Workflows

### flutter-test.yml

Runs on every PR and push to main/develop:

```yaml
- Checkout code
- Setup Flutter with caching
- Get dependencies
- Run code generation
- Analyze code
- Check formatting
- Run tests with coverage
- Upload coverage report
```

**Trigger**: PR to main/develop, push to main/develop

### flutter-build.yml

Builds artifacts on demand:

```yaml
- Checkout code
- Setup Flutter and Java
- Get dependencies
- Run code generation
- Build APK (debug or release)
- Upload artifact
```

**Trigger**: Push to main, manual dispatch

### flutter-release.yml

Creates a GitHub release with artifacts:

```yaml
- Checkout code
- Setup Flutter and Java
- Run tests (final verification)
- Build release APK and AAB
- Create draft GitHub release
- Attach artifacts
```

**Trigger**: Manual only (workflow_dispatch)

## Environment Management

### Flavors

For dev/staging/prod environments, use Flutter flavors:

```
lib/
├── main_dev.dart
├── main_staging.dart
└── main_prod.dart
```

```bash
# Development
flutter run --flavor dev -t lib/main_dev.dart

# Staging
flutter run --flavor staging -t lib/main_staging.dart

# Production
flutter run --flavor prod -t lib/main_prod.dart
```

### Environment Variables

Use `--dart-define` for build-time configuration:

```bash
flutter build apk --dart-define=API_URL=https://api.example.com
```

Access in code:

```dart
const apiUrl = String.fromEnvironment('API_URL');
```

## Secret Management

### GitHub Secrets

Store sensitive values in GitHub Secrets (Settings → Secrets and variables → Actions):

| Secret | Purpose |
|--------|---------|
| `CODECOV_TOKEN` | Code coverage upload |
| `ANDROID_KEYSTORE_BASE64` | Release signing keystore |
| `ANDROID_KEY_ALIAS` | Keystore alias |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_STORE_PASSWORD` | Keystore password |
| `FIREBASE_APP_ID` | Firebase App Distribution |
| `FIREBASE_TOKEN` | Firebase CLI authentication |

### Using Secrets in Workflows

```yaml
- name: Decode keystore
  run: echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > release.keystore

- name: Build signed APK
  env:
    KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
    KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
    STORE_PASSWORD: ${{ secrets.ANDROID_STORE_PASSWORD }}
  run: flutter build apk --release
```

### Never Commit

These files should be in `.gitignore`:
- `*.keystore`
- `*.jks`
- `key.properties`
- `.env`
- `google-services.json` (if contains API keys)
- `GoogleService-Info.plist` (if contains API keys)

## Local CI Scripts

Run CI checks locally before pushing:

```bash
# Full CI test suite
./scripts/ci/test.sh

# Build Android
./scripts/ci/build-android.sh release
```

## Customization

### Adding iOS Builds

iOS builds require macOS runners and Apple Developer setup:

```yaml
build-ios:
  runs-on: macos-latest
  steps:
    - uses: actions/checkout@v4

    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.27.0'
        channel: 'stable'
        cache: true

    - name: Install CocoaPods
      run: |
        cd ios
        pod install

    - name: Build iOS
      run: flutter build ios --release --no-codesign

    # For signed builds, add certificate/provisioning profile setup
```

### Firebase App Distribution

Add to your release workflow:

```yaml
- name: Upload to Firebase App Distribution
  uses: wzieba/Firebase-Distribution-Github-Action@v1
  with:
    appId: ${{ secrets.FIREBASE_APP_ID }}
    token: ${{ secrets.FIREBASE_TOKEN }}
    groups: testers
    file: build/app/outputs/flutter-apk/app-release.apk
```

### Play Store Upload

Use Fastlane for Play Store uploads:

```yaml
- name: Setup Ruby
  uses: ruby/setup-ruby@v1
  with:
    ruby-version: '3.0'
    bundler-cache: true

- name: Deploy to Play Store
  run: |
    cd android
    bundle exec fastlane deploy
```

## Caching

The workflows use aggressive caching for faster builds:

| Cache | Key | Restored |
|-------|-----|----------|
| Flutter SDK | `flutter-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}` | ~1 min |
| Pub cache | `pub-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}` | ~30 sec |
| Gradle | `gradle-${{ runner.os }}-${{ hashFiles('**/*.gradle*') }}` | ~2 min |

## Troubleshooting

### Tests Pass Locally But Fail in CI

1. Check Flutter version matches
2. Run `flutter clean && flutter pub get`
3. Ensure code generation is run
4. Check for platform-specific code

### Build Artifacts Missing

1. Verify the build completed successfully
2. Check artifact path matches actual output
3. Ensure artifact retention period hasn't expired

### Code Coverage Not Uploading

1. Verify `CODECOV_TOKEN` is set
2. Check coverage file exists at `coverage/lcov.info`
3. Codecov action has `continue-on-error: true` to not fail builds

## Quick Reference

```bash
# Run CI checks locally
./scripts/ci/test.sh

# Build Android locally
./scripts/ci/build-android.sh debug
./scripts/ci/build-android.sh release

# Create a release
git tag v1.2.3
git push origin v1.2.3
# Then trigger flutter-release workflow manually
```
