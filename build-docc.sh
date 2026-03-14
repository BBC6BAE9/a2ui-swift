#!/bin/sh

xcrun xcodebuild docbuild \
    -scheme A2UI \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$PWD/.derivedData"

xcrun docc process-archive transform-for-static-hosting \
    "$PWD/.derivedData/Build/Products/Debug-iphonesimulator/A2UI.doccarchive" \
    --output-path ".docs" \
    --hosting-base-path "a2ui-swiftui"

echo '<script>window.location.href += "/documentation/a2ui"</script>' > .docs/index.html
