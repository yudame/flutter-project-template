Set up CI/CD for this Flutter project.

## Steps

### 1. Verify Workflows Exist

Confirm these workflow files are present:
- `.github/workflows/flutter-test.yml` — runs on PRs
- `.github/workflows/flutter-build.yml` — builds artifacts
- `.github/workflows/flutter-release.yml` — creates releases

### 2. Check Flutter Version

Ensure the Flutter version in workflows matches your project:

1. Check `pubspec.yaml` for Flutter SDK constraint
2. Update `flutter-version` in all workflow files if needed

### 3. Test Locally

Run the CI test script to verify all checks pass:

```bash
chmod +x scripts/ci/test.sh
./scripts/ci/test.sh
```

Fix any issues before pushing.

### 4. Push and Verify

1. Create a branch and push changes
2. Open a PR to `main` or `develop`
3. Verify the `Flutter Test` workflow runs
4. Check workflow logs for any failures

### 5. (Optional) Set Up Code Coverage

To enable coverage reporting:

1. Create account at [codecov.io](https://codecov.io)
2. Connect your repository
3. Copy the upload token
4. Add `CODECOV_TOKEN` to GitHub Secrets:
   - Go to repo Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `CODECOV_TOKEN`, Value: your token

### 6. (Optional) Set Up Android Signing

For signed release builds:

1. Generate a keystore (if you don't have one):
   ```bash
   keytool -genkey -v -keystore release.keystore \
     -alias release -keyalg RSA -keysize 2048 -validity 10000
   ```

2. Base64 encode the keystore:
   ```bash
   base64 -i release.keystore -o keystore.base64
   ```

3. Add secrets to GitHub:
   - `ANDROID_KEYSTORE_BASE64`: Contents of keystore.base64
   - `ANDROID_KEY_ALIAS`: The alias you used (e.g., "release")
   - `ANDROID_KEY_PASSWORD`: Password for the key
   - `ANDROID_STORE_PASSWORD`: Password for the keystore

4. Update `flutter-release.yml` to decode and use the keystore:
   ```yaml
   - name: Decode keystore
     run: |
       echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/release.keystore

   - name: Create key.properties
     run: |
       echo "storePassword=${{ secrets.ANDROID_STORE_PASSWORD }}" > android/key.properties
       echo "keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}" >> android/key.properties
       echo "keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}" >> android/key.properties
       echo "storeFile=../release.keystore" >> android/key.properties
   ```

5. Update `android/app/build.gradle` to use key.properties for signing

### 7. (Optional) Add Firebase App Distribution

For distributing test builds:

1. Install Firebase CLI and authenticate
2. Get your Firebase App ID from the Firebase Console
3. Generate a CI token: `firebase login:ci`
4. Add secrets:
   - `FIREBASE_APP_ID`: Your app ID
   - `FIREBASE_TOKEN`: The CI token

5. Add to `flutter-build.yml`:
   ```yaml
   - name: Upload to Firebase App Distribution
     uses: wzieba/Firebase-Distribution-Github-Action@v1
     with:
       appId: ${{ secrets.FIREBASE_APP_ID }}
       token: ${{ secrets.FIREBASE_TOKEN }}
       groups: testers
       file: build/app/outputs/flutter-apk/app-release.apk
   ```

## Verification Checklist

- [ ] `flutter-test` workflow runs on PRs
- [ ] All checks pass (analyze, format, test)
- [ ] `flutter-build` creates artifacts on main
- [ ] Artifacts are downloadable from workflow run
- [ ] (Optional) Coverage reports appear on Codecov
- [ ] (Optional) Release workflow creates draft GitHub release

## Troubleshooting

### Workflow not running

- Check branch names match workflow triggers
- Verify paths-ignore isn't excluding your changes
- Check for YAML syntax errors

### Tests fail in CI but pass locally

- Ensure Flutter versions match
- Run `flutter clean && flutter pub get` locally
- Check for platform-specific test code

### Build takes too long

- Verify caching is working (check cache hit/miss in logs)
- Consider splitting into parallel jobs

## Reference

Full documentation: `docs/ci-cd.md`
