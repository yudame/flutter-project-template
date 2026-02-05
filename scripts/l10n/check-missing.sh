#!/bin/bash
# Check for missing translations in ARB files
# Compares all locale files against the English source

set -e

SOURCE="lib/l10n/app_en.arb"
MISSING_FOUND=0

if [ ! -f "$SOURCE" ]; then
    echo "❌ Source file not found: $SOURCE"
    exit 1
fi

echo "🔍 Checking translations against $SOURCE..."
echo ""

for file in lib/l10n/app_*.arb; do
    if [ "$file" != "$SOURCE" ]; then
        locale=$(basename "$file" .arb | sed 's/app_//')
        echo "📄 Checking $locale..."

        # Get keys from source (excluding metadata keys starting with @)
        source_keys=$(jq -r 'keys[]' "$SOURCE" | grep -v '^@' | sort)

        # Get keys from translation file
        trans_keys=$(jq -r 'keys[]' "$file" | grep -v '^@' | sort)

        # Find missing keys
        missing=$(comm -23 <(echo "$source_keys") <(echo "$trans_keys"))

        if [ -n "$missing" ]; then
            MISSING_FOUND=1
            echo "   ⚠️  Missing translations:"
            echo "$missing" | while read key; do
                echo "      - $key"
            done
        else
            echo "   ✅ All translations present"
        fi
        echo ""
    fi
done

if [ $MISSING_FOUND -eq 1 ]; then
    echo "❌ Some translations are missing. Please add them to the ARB files."
    exit 1
else
    echo "✅ All translations complete!"
fi
