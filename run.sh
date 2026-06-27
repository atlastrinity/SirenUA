#!/bin/bash
# Simple script to compile and run SirenUA on iOS Simulator

cd "$(dirname "$0")"

# Create a minimal Xcode project
xcodebuild -project SirenUA.xcodeproj \
    -scheme SirenUA \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    build \
    2>&1 | tail -30

if [ $? -eq 0 ]; then
    echo "Build succeeded!"
    # Launch the app on iOS Simulator
    xcrun simctl launch booted com.sirenua.app
else
    echo "Build failed!"
    exit 1
fi
