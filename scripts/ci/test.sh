#!/bin/bash
# Run full test suite for CI
# Usage: ./scripts/ci/test.sh
#
# This script runs the same checks as the GitHub Actions workflow.
# Run it locally before pushing to catch issues early.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 Running Flutter analyze..."
flutter analyze --fatal-infos

echo ""
echo "📝 Checking code format..."
dart format --set-exit-if-changed .

echo ""
echo "🧪 Running tests with coverage..."
flutter test --coverage

echo ""
echo "✅ All CI checks passed!"
