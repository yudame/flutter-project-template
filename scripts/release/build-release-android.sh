#!/bin/bash
# Build Android release (AAB for Play Store)
# Usage: ./build-release-android.sh [--apk]

set -e

echo "=== Android Release Build ==="

# Check we're in project root
if [ ! -f "pubspec.yaml" ]; then
    echo "Error: Run from project root (where pubspec.yaml is)"
    exit 1
fi

# Check key.properties exists
if [ ! -f "android/key.properties" ]; then
    echo "Error: android/key.properties not found"
    echo "Copy android/key.properties.example and fill in your signing credentials"
    exit 1
fi

# Check keystore exists
KEYSTORE_PATH=$(grep "storeFile=" android/key.properties | cut -d'=' -f2)
if [ ! -f "android/$KEYSTORE_PATH" ]; then
    echo "Error: Keystore not found at android/$KEYSTORE_PATH"
    echo "Generate with: keytool -genkey -v -keystore android/$KEYSTORE_PATH -alias release -keyalg RSA -keysize 2048 -validity 10000"
    exit 1
fi

# Get version info
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
echo "Building version: $VERSION"

# Run tests first
echo ""
echo "=== Running Tests ==="
flutter test
echo "Tests passed!"

# Clean build
echo ""
echo "=== Cleaning ==="
flutter clean
flutter pub get

# Build AAB (required for Play Store)
echo ""
echo "=== Building Android App Bundle ==="
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols

AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [ -f "$AAB_PATH" ]; then
    AAB_SIZE=$(du -h "$AAB_PATH" | cut -f1)
    echo ""
    echo "✓ AAB built successfully!"
    echo "  Path: $AAB_PATH"
    echo "  Size: $AAB_SIZE"
fi

# Optionally build APK
if [ "${1:-}" == "--apk" ]; then
    echo ""
    echo "=== Building APK ==="
    flutter build apk --release --obfuscate --split-debug-info=build/symbols

    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "$APK_PATH" ]; then
        APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
        echo ""
        echo "✓ APK built successfully!"
        echo "  Path: $APK_PATH"
        echo "  Size: $APK_SIZE"
    fi
fi

echo ""
echo "=== Build Complete ==="
echo "Version: $VERSION"
echo ""
echo "Next steps:"
echo "1. Upload AAB to Google Play Console"
echo "2. Select testing track (internal/closed/open/production)"
echo "3. Fill in release notes"
echo "4. Review and rollout"
