#!/bin/bash
# Build documentation locally using Sphinx
# Run from project root: ./docs/scripts/build_docs.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPHINX_DIR="$PROJECT_ROOT/docs/sphinx"
SOURCE_DIR="$SPHINX_DIR/source"
DOCS_DIR="$PROJECT_ROOT/docs"

# Determine Python
if [ -n "$VIRTUAL_ENV" ]; then
    PYTHON="$VIRTUAL_ENV/bin/python"
else
    PYTHON="python3"
fi

# Ensure dependencies
echo "Checking documentation dependencies..."
$PYTHON -m pip install -q sphinx sphinx-rtd-theme myst-parser linkify-it-py

# Copy markdown docs into sphinx source dir
echo "Syncing markdown files..."
cp "$DOCS_DIR/implemented.md" "$SOURCE_DIR/implemented.md"
cp "$DOCS_DIR/architecture.md" "$SOURCE_DIR/architecture.md"
cp "$DOCS_DIR/setup_reference.md" "$SOURCE_DIR/setup_reference.md"
cp "$DOCS_DIR/database.md" "$SOURCE_DIR/database.md"
cp "$DOCS_DIR/localization.md" "$SOURCE_DIR/localization.md"
cp "$DOCS_DIR/analytics.md" "$SOURCE_DIR/analytics.md"
cp "$DOCS_DIR/testing.md" "$SOURCE_DIR/testing.md"

# Build
echo "Building HTML documentation..."
cd "$SPHINX_DIR"
$PYTHON -m sphinx.cmd.build -b html source build/html

echo ""
echo "Documentation built successfully."
echo "Open: $SPHINX_DIR/build/html/index.html"
