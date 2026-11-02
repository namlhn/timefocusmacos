#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Focus.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/objects
cp Info.plist "$APP/Contents/Info.plist"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
for ARCH in x86_64 arm64; do
  swiftc -parse-as-library -O -target "${ARCH}-apple-macosx13.0" Focus.swift -o "build/objects/Focus-${ARCH}"
done
lipo -create build/objects/Focus-x86_64 build/objects/Focus-arm64 -output "$APP/Contents/MacOS/Focus"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" build/Focus-macOS.zip
printf 'Built %s and build/Focus-macOS.zip\n' "$APP"
