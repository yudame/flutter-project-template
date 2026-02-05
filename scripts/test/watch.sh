#!/bin/bash
# Watch for file changes and re-run tests (TDD workflow)

echo "👀 Watching for changes..."
echo "Press Ctrl+C to stop"
echo ""

# Check if entr is installed
if command -v entr &> /dev/null; then
    # Watch all Dart files and re-run tests on change
    find lib test -name '*.dart' | entr -c flutter test
else
    echo "⚠️  Install entr for watch mode:"
    echo "   macOS: brew install entr"
    echo "   Linux: apt-get install entr"
    echo ""
    echo "Running tests once instead..."
    flutter test
fi
