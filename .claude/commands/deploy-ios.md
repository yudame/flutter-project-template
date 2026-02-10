# Deploy to Apple App Store

Guide for deploying the iOS app to the Apple App Store.

## Prerequisites Checklist

Before deploying, verify:

- [ ] Apple Developer Program membership ($99/year)
- [ ] Signing certificates configured in Xcode
- [ ] Provisioning profiles set up
- [ ] App Store Connect app record created
- [ ] App listing complete (description, screenshots, keywords)
- [ ] Privacy policy URL configured
- [ ] Age rating questionnaire completed
- [ ] App Review information filled in (demo account if needed)

## Build Release

```bash
./scripts/release/build-release-ios.sh
```

## Archive and Upload

### Option 1: Xcode (Recommended)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device" as destination
3. Product → Archive
4. When complete, Organizer opens automatically
5. Select archive → Distribute App
6. Choose "App Store Connect"
7. Follow prompts to upload

### Option 2: Command Line

```bash
cd ios

# Archive
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  archive

# Export IPA
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist
```

### Option 3: Transporter App

1. Archive in Xcode (steps 1-4 above)
2. Export for App Store
3. Open Apple's Transporter app
4. Drag IPA file to upload

## TestFlight

After upload, the build processes (10-30 minutes).

### Internal Testing
- Up to 100 Apple Developer team members
- No review required
- Immediate access after processing

### External Testing
- Up to 10,000 testers
- Requires Beta App Review (usually < 24 hours)
- Testers need TestFlight app

## App Store Submission

1. In App Store Connect, go to your app
2. Click the "+" next to iOS App
3. Select your uploaded build
4. Fill in "What's New in This Version"
5. Submit for Review

## App Review

Typical review time: 24-48 hours (can vary)

### Common Rejection Reasons

| Issue | Solution |
|-------|----------|
| Crashes | Test on real devices before submission |
| Incomplete info | Provide demo account if login required |
| Placeholder content | Remove all test/Lorem ipsum text |
| Privacy concerns | Clearly explain data usage |
| Guideline 4.2 | Ensure app provides real value |

### If Rejected

1. Read rejection reason carefully
2. Fix the issue
3. Reply in Resolution Center (if clarification helps)
4. Resubmit for review

## Expedited Review

For critical bug fixes:
1. Submit normally
2. In App Store Connect, click "Request Expedited Review"
3. Explain the critical issue
4. Usually reviewed within 24 hours

## Post-Release

After approval:
- Monitor crash reports in App Store Connect and Sentry
- Watch user reviews for feedback
- Respond to negative reviews professionally
- Prepare next update based on feedback
