#!/bin/bash
# Build documentation for CI (GitHub Actions)
# Expects Sphinx deps already installed via workflow

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPHINX_DIR="$PROJECT_ROOT/docs/sphinx"
SOURCE_DIR="$SPHINX_DIR/source"
DOCS_DIR="$PROJECT_ROOT/docs"

# Copy markdown docs into sphinx source dir
echo "Syncing markdown files..."
cp "$DOCS_DIR/implemented.md" "$SOURCE_DIR/implemented.md"
cp "$DOCS_DIR/architecture.md" "$SOURCE_DIR/architecture.md"
cp "$DOCS_DIR/setup_reference.md" "$SOURCE_DIR/setup_reference.md"

# Build HTML (warnings as errors for CI)
echo "Building HTML documentation..."
cd "$SPHINX_DIR"
python -m sphinx.cmd.build -W -b html source build/html

# Verify output
if [ -f "build/html/index.html" ]; then
    echo "Documentation built successfully."
else
    echo "ERROR: build/html/index.html not found"
    exit 1
fi
