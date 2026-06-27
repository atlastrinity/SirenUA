#!/bin/bash
set -e

# Build Xcode project using xcodebuild
xcodebuild -project SirenUA.xcodeproj \
    -scheme SirenUA \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    build \
    -quiet

echo "Build completed successfully!"
