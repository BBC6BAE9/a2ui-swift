#!/bin/bash
set -e

# Build DocC for all targets using macOS destination
# (supports all targets including A2UIAppKit which is macOS-only)
xcrun xcodebuild docbuild \
    -scheme A2UI-Package \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$PWD/.derivedData"

PRODUCTS_DIR="$PWD/.derivedData/Build/Products/Debug"

# Dynamically find all generated .doccarchive files
ARCHIVE_COUNT=$(find "$PRODUCTS_DIR" -maxdepth 1 -name "*.doccarchive" | wc -l | tr -d ' ')

echo "Found $ARCHIVE_COUNT archive(s)"

if [ "$ARCHIVE_COUNT" -eq 0 ]; then
    echo "Error: No .doccarchive files found in $PRODUCTS_DIR"
    exit 1
elif [ "$ARCHIVE_COUNT" -eq 1 ]; then
    # Single archive: transform directly
    ARCHIVE=$(find "$PRODUCTS_DIR" -maxdepth 1 -name "*.doccarchive")
    xcrun docc process-archive transform-for-static-hosting \
        "$ARCHIVE" \
        --output-path ".docs" \
        --hosting-base-path "a2ui-swiftui"
else
    # Multiple archives: merge first, then transform (requires Xcode 15+ / docc 5.9+)
    MERGED="$PWD/.derivedData/A2UI-merged.doccarchive"
    find "$PRODUCTS_DIR" -maxdepth 1 -name "*.doccarchive" | xargs xcrun docc merge --output-path "$MERGED"

    xcrun docc process-archive transform-for-static-hosting \
        "$MERGED" \
        --output-path ".docs" \
        --hosting-base-path "a2ui-swiftui"
fi

echo '<script>window.location.href += "/documentation/a2uiswiftui"</script>' > .docs/index.html
