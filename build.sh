#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="PhoneFocus.app"
mkdir -p Model
if [[ ! -f Model/YOLOv3FP16.mlmodel ]]; then
    curl -L --fail --show-error -o Model/YOLOv3FP16.mlmodel \
        https://ml-assets.apple.com/coreml/models/Image/ObjectDetection/YOLOv3/YOLOv3FP16.mlmodel
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p .build/module-cache
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" SWIFT_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
    swiftc -parse-as-library -O -framework AppKit -framework AVFoundation -framework CoreML -framework SwiftUI -framework Vision -framework UniformTypeIdentifiers Sources/PhoneFocus.swift -o "$APP/Contents/MacOS/PhoneFocus"
cp Info.plist "$APP/Contents/Info.plist"
cp Model/YOLOv3FP16.mlmodel "$APP/Contents/Resources/YOLOv3FP16.mlmodel"
cp FallbackChime.aiff "$APP/Contents/Resources/FallbackChime.aiff"
codesign --force --deep --sign - "$APP"
echo "Built $APP"
