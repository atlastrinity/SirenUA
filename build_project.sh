#!/bin/bash
# Script to create Xcode project for SirenUA iOS app

cd "$(dirname "$0")"

# Create Xcode project using xcodebuild
xcodebuild -project SirenUA.xcodeproj \
    -scheme SirenUA \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    build

echo "Build completed!"
