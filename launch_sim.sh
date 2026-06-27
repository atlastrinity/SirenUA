#!/bin/bash
xcodegen generate
xcodebuild -project SirenUA.xcodeproj -scheme SirenUA -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build > build_log.txt 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
    # Install app to booted simulator
    app_path=$(find DerivedData -name "SirenUA.app" | head -n 1)
    if [ -n "$app_path" ]; then
        xcrun simctl install booted "$app_path"
        xcrun simctl launch booted com.sirenua.SirenUA
    else
        # Try finding it in default Xcode derived data
        app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "SirenUA.app" | head -n 1)
        xcrun simctl install booted "$app_path"
        xcrun simctl launch booted com.sirenua.SirenUA
    fi
else
    echo "❌ Build failed! Check build_log.txt"
    tail -n 20 build_log.txt
fi
