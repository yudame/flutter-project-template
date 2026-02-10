# Plan: Mobile CI/CD Pipeline Documentation & Workflows

**Tracking**: https://github.com/yudame/flutter-project-template/issues/1

## Goal

Add CI/CD documentation and GitHub Actions workflows for Flutter mobile app builds — enabling automated testing on PRs, build artifact generation, and release workflows.

## Current State

- **Existing infrastructure**:
  - `.github/workflows/docs.yml` — builds and deploys Sphinx docs to GitHub Pages
  - `scripts/test/run-all.sh` — runs all tests locally
  - `scripts/test/coverage.sh` — runs tests with coverage
  - `scripts/setup.sh` — project setup script
- **Missing**:
  - No Flutter test workflow for PRs
  - No Flutter build workflow for artifacts
  - No release workflow
  - No CI/CD documentation
  - No CI-specific scripts

## Approach

Create a practical CI/CD setup that works out of the box for Flutter projects:

1. **Test workflow** — runs on every PR, fast feedback
2. **Build workflow** — creates artifacts on demand or on main
3. **Release workflow** — manual trigger for production releases
4. **Documentation** — explains conventions and customization

**Key decisions**:
1. **Android builds only in CI** — iOS requires macOS runners + signing setup (document, don't automate)
2. **Use Flutter's official action** — `subosito/flutter-action` is well-maintained
3. **Aggressive caching** — Flutter SDK, pub cache, Gradle cache
4. **Keep workflows simple** — teams can extend as needed
5. **No signing in workflows** — document patterns, don't commit secrets setup

---

## Files to Create

### 1. `docs/ci-cd.md`

Comprehensive documentation covering:

- **Branch strategy**: main (production), develop (integration), feature/* (work in progress)
- **PR workflow**: Tests must pass, require review, squash merge
- **Version numbering**: Semantic versioning (MAJOR.MINOR.PATCH+BUILD)
- **Build triggers**:
  - PRs: test only (fast)
  - Main: test + build artifacts
  - Manual: release workflow
- **Environment management**: dev/staging/prod flavor patterns
- **Secret management**: GitHub Secrets for signing keys, API keys
- **Customization guide**: How to add iOS builds, Firebase App Distribution, etc.

### 2. `.github/workflows/flutter-test.yml`

Test workflow (runs on every PR):

```yaml
name: Flutter Test

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
          channel: 'stable'
          cache: true

      - name: Get dependencies
        run: flutter pub get

      - name: Run code generation
        run: flutter pub run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: flutter analyze --fatal-infos

      - name: Format check
        run: dart format --set-exit-if-changed .

      - name: Run tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: coverage/lcov.info
        continue-on-error: true
```

### 3. `.github/workflows/flutter-build.yml`

Build workflow (artifacts on demand):

```yaml
name: Flutter Build

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      build_type:
        description: 'Build type'
        required: true
        default: 'debug'
        type: choice
        options:
          - debug
          - release

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
          channel: 'stable'
          cache: true

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
          cache: 'gradle'

      - name: Get dependencies
        run: flutter pub get

      - name: Run code generation
        run: flutter pub run build_runner build --delete-conflicting-outputs

      - name: Build APK
        run: flutter build apk --${{ github.event.inputs.build_type || 'debug' }}

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: app-${{ github.event.inputs.build_type || 'debug' }}
          path: build/app/outputs/flutter-apk/app-*.apk
```

### 4. `.github/workflows/flutter-release.yml`

Release workflow (manual trigger):

```yaml
name: Flutter Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version (e.g., 1.2.0)'
        required: true

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
          channel: 'stable'
          cache: true

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
          cache: 'gradle'

      - name: Get dependencies
        run: flutter pub get

      - name: Run code generation
        run: flutter pub run build_runner build --delete-conflicting-outputs

      - name: Run tests
        run: flutter test

      - name: Build release APK
        run: flutter build apk --release

      - name: Build release AAB
        run: flutter build appbundle --release

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v${{ github.event.inputs.version }}
          name: Release ${{ github.event.inputs.version }}
          draft: true
          files: |
            build/app/outputs/flutter-apk/app-release.apk
            build/app/outputs/bundle/release/app-release.aab
```

### 5. `scripts/ci/test.sh`

CI test script (can run locally too):

```bash
#!/bin/bash
# Run full test suite for CI
# Usage: ./scripts/ci/test.sh

set -e

echo "🔍 Running Flutter analyze..."
flutter analyze --fatal-infos

echo "📝 Checking format..."
dart format --set-exit-if-changed .

echo "🧪 Running tests with coverage..."
flutter test --coverage

echo "✅ All CI checks passed!"
```

### 6. `scripts/ci/build-android.sh`

Android build script:

```bash
#!/bin/bash
# Build Android APK/AAB
# Usage: ./scripts/ci/build-android.sh [debug|release]

set -e

BUILD_TYPE="${1:-debug}"

echo "🏗️ Building Android ($BUILD_TYPE)..."

flutter build apk --$BUILD_TYPE

if [ "$BUILD_TYPE" == "release" ]; then
  echo "📦 Building App Bundle..."
  flutter build appbundle --release
fi

echo "✅ Android build complete!"
echo "APK: build/app/outputs/flutter-apk/"
```

### 7. `.claude/commands/setup-ci.md`

Claude command for CI setup:

```markdown
Set up CI/CD for this Flutter project.

## Steps

### 1. Verify Workflows Exist

Check that these files exist:
- `.github/workflows/flutter-test.yml`
- `.github/workflows/flutter-build.yml`
- `.github/workflows/flutter-release.yml`

### 2. Update Flutter Version

Check `pubspec.yaml` for Flutter version constraints and update workflows to match.

### 3. Test Locally

Run the CI test script locally to verify it passes:
```bash
./scripts/ci/test.sh
```

### 4. Push and Verify

Push to a branch, create a PR, and verify the test workflow runs.

### 5. (Optional) Set Up Code Coverage

1. Create account at codecov.io
2. Add `CODECOV_TOKEN` to GitHub Secrets
3. Update workflow to use token

### 6. (Optional) Set Up Android Signing

For release builds:
1. Generate keystore: `keytool -genkey -v -keystore release.keystore -alias release -keyalg RSA -keysize 2048 -validity 10000`
2. Encode keystore: `base64 release.keystore > keystore.base64`
3. Add to GitHub Secrets:
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_STORE_PASSWORD`
4. Update build workflow to decode and use keystore

## Verification

1. Create a PR with a small change
2. Verify flutter-test workflow runs and passes
3. Merge to main
4. Verify flutter-build workflow creates artifacts
```

### 8. Update `docs/sphinx/source/index.rst`

Add ci-cd to the toctree.

### 9. Update build scripts

Add `cp "$DOCS_DIR/ci-cd.md" "$SOURCE_DIR/ci-cd.md"` to both build scripts.

---

## What We're NOT Doing

- **No iOS builds in CI** — requires macOS runners + Apple Developer setup. Document the pattern only.
- **No signing configuration** — too project-specific. Document patterns, don't implement.
- **No Firebase App Distribution** — optional, document as extension
- **No Play Store upload** — requires service account setup, document only
- **No complex matrix builds** — keep simple, teams extend as needed

## How It Fits Together

```
┌─────────────────────────────────────────────────────────────────┐
│                       GitHub Actions                             │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │  flutter-test    │  │  flutter-build   │  │ flutter-release│ │
│  │                  │  │                  │  │                │ │
│  │  On: PR, push    │  │  On: main, manual│  │  On: manual    │ │
│  │                  │  │                  │  │                │ │
│  │  • analyze       │  │  • build APK     │  │  • test        │ │
│  │  • format        │  │  • upload        │  │  • build APK   │ │
│  │  • test          │  │    artifact      │  │  • build AAB   │ │
│  │  • coverage      │  │                  │  │  • GH release  │ │
│  └──────────────────┘  └──────────────────┘  └────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                       Local Scripts                              │
│                                                                  │
│  scripts/ci/test.sh          scripts/ci/build-android.sh        │
│  • Same checks as CI         • Build APK/AAB locally             │
│  • Run before pushing        • Test release builds               │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Structure After Implementation

```
flutter-project-template/
├── .github/
│   └── workflows/
│       ├── docs.yml              # (existing)
│       ├── flutter-test.yml      # Test on PR
│       ├── flutter-build.yml     # Build artifacts
│       └── flutter-release.yml   # Release workflow
├── scripts/
│   ├── ci/
│   │   ├── test.sh               # CI test script
│   │   └── build-android.sh      # Android build script
│   └── ...
├── docs/
│   └── ci-cd.md                  # CI/CD documentation
└── .claude/
    └── commands/
        └── setup-ci.md           # CI setup command
```

## Estimated Work

~8 files. Workflows are straightforward, documentation explains customization. One focused session.
