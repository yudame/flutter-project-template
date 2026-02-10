#!/bin/bash
# Bump version in pubspec.yaml
# Usage: ./bump-version.sh [major|minor|patch]

set -e

PUBSPEC="pubspec.yaml"

if [ ! -f "$PUBSPEC" ]; then
    echo "Error: pubspec.yaml not found. Run from project root."
    exit 1
fi

# Get current version
CURRENT_VERSION=$(grep "^version:" "$PUBSPEC" | sed 's/version: //')
echo "Current version: $CURRENT_VERSION"

# Parse version components
VERSION_PART=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)

MAJOR=$(echo "$VERSION_PART" | cut -d'.' -f1)
MINOR=$(echo "$VERSION_PART" | cut -d'.' -f2)
PATCH=$(echo "$VERSION_PART" | cut -d'.' -f3)

# Increment based on argument
case "${1:-patch}" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "Usage: $0 [major|minor|patch]"
        exit 1
        ;;
esac

# Always increment build number
BUILD_NUMBER=$((BUILD_NUMBER + 1))

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}+${BUILD_NUMBER}"
echo "New version: $NEW_VERSION"

# Update pubspec.yaml
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
else
    # Linux
    sed -i "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
fi

echo "Updated $PUBSPEC"

# Git commit
if [ "${2:-}" != "--no-commit" ]; then
    git add "$PUBSPEC"
    git commit -m "chore: bump version to $NEW_VERSION"
    echo "Committed version bump"

    # Create tag
    git tag "v${MAJOR}.${MINOR}.${PATCH}"
    echo "Created tag v${MAJOR}.${MINOR}.${PATCH}"
fi

echo ""
echo "Version bumped to $NEW_VERSION"
echo "To push: git push && git push --tags"
