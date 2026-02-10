#!/bin/bash
# Generate changelog from git commits since last tag
# Usage: ./changelog.sh [--update]

set -e

# Get the last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LAST_TAG" ]; then
    echo "No previous tags found. Showing all commits."
    RANGE="HEAD"
else
    echo "Changes since $LAST_TAG:"
    RANGE="${LAST_TAG}..HEAD"
fi

echo ""

# Function to extract commits by type
extract_commits() {
    local prefix=$1
    local title=$2
    local commits=$(git log "$RANGE" --pretty=format:"%s" 2>/dev/null | grep "^${prefix}" | sed "s/^${prefix}: /- /" || true)
    if [ -n "$commits" ]; then
        echo "### $title"
        echo "$commits"
        echo ""
    fi
}

# Generate changelog content
generate_changelog() {
    echo "## Changelog"
    echo ""

    extract_commits "feat" "Features"
    extract_commits "fix" "Bug Fixes"
    extract_commits "perf" "Performance"
    extract_commits "refactor" "Refactoring"
    extract_commits "docs" "Documentation"
    extract_commits "test" "Tests"
    extract_commits "chore" "Chores"

    # Uncategorized commits
    UNCATEGORIZED=$(git log "$RANGE" --pretty=format:"%s" 2>/dev/null | grep -v "^feat\|^fix\|^perf\|^refactor\|^docs\|^test\|^chore" | sed 's/^/- /' || true)
    if [ -n "$UNCATEGORIZED" ]; then
        echo "### Other"
        echo "$UNCATEGORIZED"
        echo ""
    fi
}

CHANGELOG_CONTENT=$(generate_changelog)

echo "$CHANGELOG_CONTENT"

# Optionally update CHANGELOG.md
if [ "${1:-}" == "--update" ]; then
    VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
    DATE=$(date +%Y-%m-%d)

    echo ""
    echo "Updating CHANGELOG.md..."

    # Create header for this version
    VERSION_HEADER="## [$VERSION] - $DATE"

    # Check if CHANGELOG.md exists
    if [ -f "CHANGELOG.md" ]; then
        # Insert new version after the title
        {
            head -n 2 CHANGELOG.md
            echo ""
            echo "$VERSION_HEADER"
            echo ""
            echo "$CHANGELOG_CONTENT" | tail -n +3  # Skip the "## Changelog" header
            tail -n +3 CHANGELOG.md
        } > CHANGELOG.tmp
        mv CHANGELOG.tmp CHANGELOG.md
    else
        # Create new CHANGELOG.md
        {
            echo "# Changelog"
            echo ""
            echo "All notable changes to this project will be documented in this file."
            echo ""
            echo "$VERSION_HEADER"
            echo ""
            echo "$CHANGELOG_CONTENT" | tail -n +3
        } > CHANGELOG.md
    fi

    echo "Updated CHANGELOG.md with version $VERSION"
fi
