#!/bin/bash
# Run tests with coverage and generate HTML report

set -e

echo "📊 Running tests with coverage..."
echo ""

# Run tests with coverage
flutter test --coverage

echo ""

# Check if lcov is installed for HTML report
if command -v lcov &> /dev/null && command -v genhtml &> /dev/null; then
    echo "📄 Generating HTML report..."

    # Remove generated files from coverage (they skew the numbers)
    lcov --remove coverage/lcov.info \
        '*.freezed.dart' \
        '*.g.dart' \
        '*.gr.dart' \
        '*.config.dart' \
        'lib/l10n/generated/*' \
        -o coverage/lcov.info \
        --quiet

    # Generate HTML report
    genhtml coverage/lcov.info \
        -o coverage/html \
        --quiet

    echo "✅ Coverage report generated: coverage/html/index.html"
    echo ""

    # Show summary
    lcov --summary coverage/lcov.info 2>/dev/null || true

    # Open report on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo ""
        echo "Opening coverage report..."
        open coverage/html/index.html
    fi
else
    echo "⚠️  Install lcov for HTML reports:"
    echo "   macOS: brew install lcov"
    echo "   Linux: apt-get install lcov"
    echo ""
    echo "📄 Raw coverage data available at: coverage/lcov.info"
fi
