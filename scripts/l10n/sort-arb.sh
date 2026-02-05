#!/bin/bash
# Sort ARB file keys alphabetically
# Keeps files consistent and easier to diff

set -e

echo "🔤 Sorting ARB files..."

for file in lib/l10n/app_*.arb; do
    echo "   Sorting $file..."
    # jq -S sorts keys alphabetically
    jq -S '.' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
done

echo "✅ All ARB files sorted!"
