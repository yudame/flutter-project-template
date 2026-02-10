# Deployment Plan

**Issue:** https://github.com/yudame/flutter-project-template/issues/4

## Overview

Create comprehensive app store deployment documentation and scripts for both iOS (App Store) and Android (Play Store). This builds on the CI/CD pipeline (issue #1) to provide the final step: releasing to production.

## Deliverables

### 1. Documentation (`docs/deployment.md`)

Comprehensive deployment guide covering:

#### Pre-Release Checklist
- App icons (all platform-specific sizes)
- Splash screens and launch images
- App signing setup (Android keystore, iOS certificates)
- Privacy policy URL requirement
- Store listing content (screenshots, descriptions)

#### Android Deployment
- Keystore generation: `keytool -genkey -v -keystore release.keystore -alias release -keyalg RSA -keysize 2048 -validity 10000`
- `key.properties` setup (gitignored, never committed)
- AAB vs APK: Play Store requires AAB for new apps
- Play Console walkthrough
- Internal testing track for beta distribution (Android's TestFlight equivalent)
- Testing tracks: internal → closed → open → production
- Staged rollouts (1% → 5% → 20% → 100%)

#### iOS Deployment
- Apple Developer Program ($99/year requirement)
- Certificates: Development, Distribution
- Provisioning profiles: Development, App Store
- App Store Connect setup
- TestFlight for beta distribution
- App Review guidelines and common rejection reasons

Note: Both platforms have beta testing mechanisms - Android uses Internal/Closed testing tracks, iOS uses TestFlight.

#### Versioning Strategy
- Semantic versioning in `pubspec.yaml`: `version: 1.2.3+45`
- Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`
- Build number must always increment
- Changelog management with git tags

### 2. Configuration Templates

#### `android/key.properties.example`
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=release
storeFile=../release.keystore
```

#### `ios/ExportOptions.plist.example`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

#### `.env.production.example`
```bash
API_URL=https://api.yourapp.com
SENTRY_DSN=https://xxx@sentry.io/xxx
ANALYTICS_KEY=your_production_key
```

### 3. Shell Scripts (`scripts/release/`)

#### `bump-version.sh`
- Parse current version from pubspec.yaml
- Increment patch/minor/major based on argument
- Auto-increment build number
- Update pubspec.yaml
- Git commit the version bump

#### `build-release-android.sh`
- Verify key.properties exists
- Run tests first
- Build signed AAB for Play Store
- Optionally build APK for direct distribution
- Output location and file sizes

#### `build-release-ios.sh`
- Verify certificates and provisioning
- Run tests first
- Build archive
- Export IPA using ExportOptions.plist
- Output location

#### `changelog.sh`
- Generate changelog from git commits since last tag
- Group by type (feat, fix, docs, etc.)
- Output markdown format
- Optionally update CHANGELOG.md

### 4. Claude Commands (`.claude/commands/`)

#### `prepare-release.md`
- Run full test suite
- Bump version (prompt for type)
- Build release artifacts (Android + iOS)
- Generate changelog
- Create git tag
- Summarize what's ready for deployment

#### `deploy-android.md`
- Prerequisites checklist
- Step-by-step Play Console upload
- Testing track selection guidance
- Rollout percentage recommendations

#### `deploy-ios.md`
- Prerequisites checklist
- App Store Connect upload via Xcode or Transporter
- TestFlight setup
- App Review submission

### 5. Update Sphinx Docs
- Add deployment.md to sphinx source
- Update index.rst with Deployment section
- Update build scripts to copy deployment.md

## Implementation Order

1. Create `docs/deployment.md` - comprehensive documentation
2. Create configuration templates
3. Create shell scripts in `scripts/release/`
4. Create Claude commands
5. Update Sphinx documentation
6. Test scripts locally
7. Commit and close issue

## Dependencies

- Issue #1 (CI/CD) - COMPLETED
- Existing CI scripts provide foundation for release scripts

## Security Considerations

- Never commit keystores, certificates, or passwords
- Use `.gitignore` for sensitive files
- Document GitHub Secrets for CI signing
- Provide `.example` templates only
