#!/bin/bash
# Run all tests with expanded output

set -e

echo "🧪 Running all tests..."
echo ""

flutter test --reporter=expanded

echo ""
echo "✅ All tests passed!"
