# Deploy to Google Play Store

Guide for deploying the Android app to Google Play Store.

## Prerequisites Checklist

Before deploying, verify:

- [ ] `android/key.properties` exists with valid credentials
- [ ] Release keystore is available
- [ ] Google Play Console access is set up
- [ ] App listing is complete (description, screenshots, etc.)
- [ ] Privacy policy URL is configured
- [ ] Content rating questionnaire completed

## Build Release

```bash
./scripts/release/build-release-android.sh
```

This creates: `build/app/outputs/bundle/release/app-release.aab`

## Upload to Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Navigate to: Release → Production (or testing track)
4. Click "Create new release"
5. Upload the AAB file
6. Add release notes
7. Review and start rollout

## Testing Track Recommendations

| Track | When to Use |
|-------|-------------|
| Internal | Quick internal testing, immediate access |
| Closed | Beta testing with select users |
| Open | Public beta, anyone can join |
| Production | Full public release |

**Recommended flow:** Internal → Closed → Production

## Staged Rollout

For production releases:

1. Start at **1%** - catch critical issues early
2. Wait 24-48 hours, check for crashes
3. Increase to **5%** if stable
4. Wait another 24 hours
5. Increase to **20%**
6. Full rollout to **100%**

Monitor crash rates in Play Console throughout.

## Common Issues

| Issue | Solution |
|-------|----------|
| Version code already exists | Increment build number in pubspec.yaml |
| Signing key mismatch | Ensure using same keystore as previous releases |
| AAB too large | Enable Android App Bundle, remove unused assets |
| Rejected for policy | Review rejection reason, fix and resubmit |

## Post-Deploy Monitoring

After deployment:
- Monitor crash reports in Play Console and Sentry
- Watch user reviews for issues
- Check analytics for behavior changes
- Be ready to halt rollout if issues found
