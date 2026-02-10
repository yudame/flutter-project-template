# Prepare Release

Prepare the app for release to app stores.

## Steps

1. **Run full test suite**
   ```bash
   flutter test
   ```
   Ensure all tests pass before proceeding.

2. **Check code quality**
   ```bash
   dart format --set-exit-if-changed .
   dart analyze
   ```

3. **Bump version**
   Ask which type of version bump is needed:
   - **patch** (1.0.0 → 1.0.1): Bug fixes only
   - **minor** (1.0.0 → 1.1.0): New features, backward compatible
   - **major** (1.0.0 → 2.0.0): Breaking changes

   ```bash
   ./scripts/release/bump-version.sh [patch|minor|major]
   ```

4. **Generate changelog**
   ```bash
   ./scripts/release/changelog.sh --update
   ```
   Review the generated changelog and edit if needed.

5. **Build release artifacts**

   For Android:
   ```bash
   ./scripts/release/build-release-android.sh
   ```

   For iOS (requires macOS):
   ```bash
   ./scripts/release/build-release-ios.sh
   ```

6. **Verify builds**
   - Check AAB size (Android should be < 150MB)
   - Test on real devices if possible
   - Verify version numbers are correct

7. **Push to remote**
   ```bash
   git push && git push --tags
   ```

8. **Summary**
   Report:
   - New version number
   - Changelog summary
   - Build artifact locations
   - Next steps for store submission

## Notes

- Always run tests before building releases
- Keep build artifacts locally until store review passes
- For hotfixes, use patch version bump
