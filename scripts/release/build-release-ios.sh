#!/bin/bash
# Build iOS release
# Usage: ./build-release-ios.sh

set -e

echo "=== iOS Release Build ==="

# Check we're in project root
if [ ! -f "pubspec.yaml" ]; then
    echo "Error: Run from project root (where pubspec.yaml is)"
    exit 1
fi

# Check we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: iOS builds require macOS"
    exit 1
fi

# Check Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode command line tools not found"
    echo "Install with: xcode-select --install"
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

# Install CocoaPods dependencies
echo ""
echo "=== Installing CocoaPods ==="
cd ios
pod install --repo-update
cd ..

# Build iOS release
echo ""
echo "=== Building iOS Release ==="
flutter build ios --release --obfuscate --split-debug-info=build/symbols

echo ""
echo "✓ iOS build complete!"
echo ""
echo "=== Next Steps ==="
echo ""
echo "Option 1: Archive in Xcode (Recommended)"
echo "  1. Open ios/Runner.xcworkspace in Xcode"
echo "  2. Select 'Any iOS Device' as destination"
echo "  3. Product → Archive"
echo "  4. In Organizer: Distribute App → App Store Connect"
echo ""
echo "Option 2: Command line archive"
echo "  cd ios"
echo "  xcodebuild -workspace Runner.xcworkspace \\"
echo "    -scheme Runner \\"
echo "    -configuration Release \\"
echo "    -archivePath build/Runner.xcarchive \\"
echo "    archive"
echo ""
echo "  xcodebuild -exportArchive \\"
echo "    -archivePath build/Runner.xcarchive \\"
echo "    -exportPath build/ipa \\"
echo "    -exportOptionsPlist ExportOptions.plist"
echo ""
echo "Option 3: Use Transporter app"
echo "  After archiving, use Apple's Transporter app to upload"
