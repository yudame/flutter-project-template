# App Store Deployment Guide

This guide covers deploying Flutter apps to Google Play Store and Apple App Store.

## Pre-Release Checklist

Before deploying to any store, ensure you have:

### Assets
- [ ] App icon in all required sizes (use flutter_launcher_icons)
- [ ] Splash screen configured (use flutter_native_splash)
- [ ] Store screenshots (phone, tablet sizes)
- [ ] Feature graphic (Android: 1024x500)
- [ ] App preview video (optional but recommended)

### Legal & Content
- [ ] Privacy policy URL (required by both stores)
- [ ] Terms of service URL (recommended)
- [ ] Age rating questionnaire completed
- [ ] Content descriptions written

### Technical
- [ ] App signing configured (see platform sections below)
- [ ] Production API endpoints configured
- [ ] Analytics/crash reporting enabled
- [ ] All debug flags disabled

## Version Management

### Semantic Versioning

Flutter uses `version` in `pubspec.yaml`:

```yaml
version: 1.2.3+45
#        │ │ │  └── Build number (must always increment)
#        │ │ └───── Patch (bug fixes)
#        │ └─────── Minor (new features, backward compatible)
#        └───────── Major (breaking changes)
```

### Version Bumping

Use the provided script:

```bash
# Bump patch version (1.0.0 → 1.0.1)
./scripts/release/bump-version.sh patch

# Bump minor version (1.0.1 → 1.1.0)
./scripts/release/bump-version.sh minor

# Bump major version (1.1.0 → 2.0.0)
./scripts/release/bump-version.sh major
```

The script automatically:
- Increments the specified version component
- Increments the build number
- Updates pubspec.yaml
- Creates a git commit

### Changelog Management

Generate changelog from git commits:

```bash
./scripts/release/changelog.sh
```

This parses conventional commits (feat:, fix:, docs:, etc.) since the last tag.

## Android Deployment

### 1. Create Release Keystore

Generate a keystore for signing release builds:

```bash
keytool -genkey -v \
  -keystore android/release.keystore \
  -alias release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

**IMPORTANT**:
- Store the keystore file securely (NOT in git)
- Save the passwords - you cannot recover them
- Back up the keystore - losing it means you can't update your app

### 2. Configure Signing

Create `android/key.properties` (gitignored):

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=release
storeFile=release.keystore
```

The template's `android/app/build.gradle` already references this file.

### 3. Build Release

```bash
# Build Android App Bundle (required for Play Store)
./scripts/release/build-release-android.sh

# Or manually:
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### 4. Google Play Console Setup

1. Create developer account ($25 one-time fee)
2. Create new app in Play Console
3. Complete store listing:
   - App name, description
   - Screenshots, graphics
   - Privacy policy URL
   - Category and tags
4. Content rating questionnaire
5. Target audience and content
6. App access (if login required, provide test credentials)

### 5. Release Tracks

Play Store offers graduated release tracks:

| Track | Audience | Purpose |
|-------|----------|---------|
| Internal | Up to 100 testers | Quick internal testing |
| Closed | Invite-only | Beta testing with select users |
| Open | Anyone can join | Public beta |
| Production | Everyone | Full release |

**Recommended flow**: Internal → Closed → Production

### 6. Staged Rollouts

For production releases, use staged rollouts:

1. Start at 1% - catch critical issues early
2. Increase to 5% after 24-48 hours if stable
3. Increase to 20% after another day
4. Full rollout at 100%

Monitor crash rates and user feedback at each stage.

## iOS Deployment

### 1. Apple Developer Program

- Enroll at developer.apple.com ($99/year)
- Wait for approval (usually 24-48 hours)
- This is required for App Store distribution

### 2. Certificates & Provisioning

#### Using Xcode (Recommended)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target → Signing & Capabilities
3. Select your team
4. Enable "Automatically manage signing"

Xcode handles certificates and provisioning profiles automatically.

#### Manual Setup

If you need manual control:

1. Create certificates in Apple Developer portal:
   - iOS Distribution certificate

2. Create App ID matching your bundle identifier

3. Create provisioning profile:
   - App Store distribution profile
   - Link to your certificate and App ID

4. Download and install in Xcode

### 3. Build Release

```bash
# Build iOS release
./scripts/release/build-release-ios.sh

# Or manually:
flutter build ios --release
```

Then archive and export in Xcode:
1. Product → Archive
2. Distribute App → App Store Connect
3. Upload

### 4. App Store Connect Setup

1. Create new app in App Store Connect
2. Complete app information:
   - App name, subtitle, description
   - Keywords (100 characters max)
   - Screenshots for all device sizes
   - Privacy policy URL
3. Configure app pricing
4. Set up age rating

### 5. TestFlight

TestFlight allows beta testing before App Store release:

1. Upload build via Xcode or Transporter app
2. Wait for processing (10-30 minutes)
3. Add internal testers (up to 100, instant access)
4. Add external testers (up to 10,000, requires review)

### 6. App Review

Apple reviews all apps before release. Common rejection reasons:

| Issue | Solution |
|-------|----------|
| Crashes or bugs | Test thoroughly on real devices |
| Incomplete info | Provide demo account if login required |
| Placeholder content | Remove all Lorem ipsum, test data |
| Privacy issues | Clearly explain data collection |
| Guideline 4.2 (minimum functionality) | Ensure app provides real value |

Review typically takes 24-48 hours, sometimes longer.

## CI/CD Integration

### GitHub Secrets

Store sensitive values as GitHub Secrets:

```
# Android
ANDROID_KEYSTORE_BASE64    # base64-encoded keystore file
ANDROID_KEY_ALIAS          # Key alias
ANDROID_KEY_PASSWORD       # Key password
ANDROID_STORE_PASSWORD     # Keystore password

# iOS
APPLE_CERTIFICATE_BASE64   # base64-encoded .p12 certificate
APPLE_CERTIFICATE_PASSWORD # Certificate password
APPLE_PROVISIONING_BASE64  # base64-encoded .mobileprovision
APPLE_TEAM_ID             # Apple Developer Team ID
```

### Automated Release Workflow

The template includes `.github/workflows/flutter-release.yml` which:

1. Triggers on version tags (`v*`)
2. Runs full test suite
3. Builds signed Android AAB
4. Builds iOS archive (on macOS runner)
5. Creates GitHub release with artifacts

## Environment Configuration

### Production Environment

Create `.env.production`:

```bash
API_URL=https://api.yourapp.com
SENTRY_DSN=https://xxx@sentry.io/xxx
ANALYTICS_KEY=your_production_key
ENABLE_ANALYTICS=true
```

Load with flutter_dotenv or envied package.

### Build Flavors

For multiple environments, use Flutter flavors:

```bash
# Development
flutter run --flavor development

# Staging
flutter run --flavor staging

# Production
flutter build appbundle --flavor production --release
```

Configure in `android/app/build.gradle` and Xcode schemes.

## Post-Release

### Monitoring

After release, monitor:

- **Crash rates** via Sentry or Firebase Crashlytics
- **User reviews** in store consoles
- **Analytics** for user behavior changes
- **Performance** metrics (app start time, etc.)

### Hotfixes

For critical bugs:

1. Create fix on main branch
2. Bump patch version
3. Build and test
4. Use expedited review (iOS) or staged rollout (Android)

### Update Frequency

Recommended release cadence:

- **Hotfixes**: As needed for critical bugs
- **Patch releases**: Every 1-2 weeks for bug fixes
- **Minor releases**: Monthly for new features
- **Major releases**: Quarterly for significant updates

## Security Best Practices

1. **Never commit secrets**: Use .gitignore for keystores, .env files
2. **Use GitHub Secrets**: For CI/CD signing credentials
3. **Rotate keys**: If credentials are exposed, rotate immediately
4. **Code obfuscation**: Enable for release builds
5. **SSL pinning**: For sensitive API communications

```bash
# Enable obfuscation in Flutter
flutter build appbundle --obfuscate --split-debug-info=build/symbols
```

## Troubleshooting

### Android

| Problem | Solution |
|---------|----------|
| Keystore not found | Check path in key.properties |
| Signing failed | Verify passwords match |
| AAB too large | Enable app bundles, remove unused assets |
| Version code exists | Increment build number in pubspec.yaml |

### iOS

| Problem | Solution |
|---------|----------|
| Provisioning issue | Regenerate in Apple Developer portal |
| Archive fails | Clean build folder, check signing |
| Upload fails | Check network, try Transporter app |
| Processing stuck | Wait up to 1 hour, contact Apple if longer |
