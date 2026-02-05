#!/bin/bash
# Initial project setup script

set -e

echo "🚀 Setting up Flutter project..."
echo ""

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    echo "   https://docs.flutter.dev/get-started/install"
    exit 1
fi

# Show Flutter version
echo "📱 Flutter version:"
flutter --version
echo ""

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get
echo ""

# Generate localization files
echo "🌍 Generating localization files..."
flutter gen-l10n
echo ""

# Run code generation
echo "⚙️ Running code generation..."
flutter pub run build_runner build --delete-conflicting-outputs
echo ""

# Run analysis (warnings only, don't fail)
echo "🔍 Running analysis..."
flutter analyze --no-fatal-infos || true
echo ""

# Run tests
echo "🧪 Running tests..."
flutter test
echo ""

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  make run     - Start the app"
echo "  make test    - Run tests"
echo "  make help    - Show all commands"
