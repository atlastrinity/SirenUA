#!/bin/bash
set -e

# Clean up any existing project
rm -rf SirenUA.xcodeproj

# Create Xcode project using xcodebuild
xcodebuild -project SirenUA.xcodeproj \
    -scheme SirenUA \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    build \
    -quiet

echo "Build completed successfully!"
