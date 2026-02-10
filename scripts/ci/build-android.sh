#!/bin/bash
# Build Android APK/AAB
# Usage: ./scripts/ci/build-android.sh [debug|release]
#
# Examples:
#   ./scripts/ci/build-android.sh          # Builds debug APK
#   ./scripts/ci/build-android.sh debug    # Builds debug APK
#   ./scripts/ci/build-android.sh release  # Builds release APK + AAB

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

BUILD_TYPE="${1:-debug}"

if [[ "$BUILD_TYPE" != "debug" && "$BUILD_TYPE" != "release" ]]; then
  echo "❌ Invalid build type: $BUILD_TYPE"
  echo "Usage: $0 [debug|release]"
  exit 1
fi

echo "🏗️ Building Android ($BUILD_TYPE)..."
echo ""

# Ensure dependencies and codegen are up to date
echo "📦 Getting dependencies..."
flutter pub get

echo ""
echo "⚙️ Running code generation..."
flutter pub run build_runner build --delete-conflicting-outputs

echo ""
echo "🔨 Building APK..."
flutter build apk --$BUILD_TYPE

if [ "$BUILD_TYPE" == "release" ]; then
  echo ""
  echo "📦 Building App Bundle..."
  flutter build appbundle --release
fi

echo ""
echo "✅ Android build complete!"
echo ""
echo "Output:"
echo "  APK: build/app/outputs/flutter-apk/app-$BUILD_TYPE.apk"
if [ "$BUILD_TYPE" == "release" ]; then
  echo "  AAB: build/app/outputs/bundle/release/app-release.aab"
fi
