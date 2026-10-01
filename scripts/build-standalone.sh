#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcodebuild -project "$project_root/SlidePilot.xcodeproj" \
    -scheme "SlidePilot Standalone" -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$project_root/build/Standalone" build
mkdir -p "$project_root/dist"
ditto "$project_root/build/Standalone/Build/Products/Release/SlidePilot.app" "$project_root/dist/SlidePilot.app"
codesign --verify --deep --strict "$project_root/dist/SlidePilot.app"
printf '\nStandalone app: %s\n' "$project_root/dist/SlidePilot.app"
