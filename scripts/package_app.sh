#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${APP_NAME:-Type4Me}"
APP_EXECUTABLE="${APP_EXECUTABLE:-Type4Me}"
APP_ICON_NAME="${APP_ICON_NAME:-AppIcon}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.type4me.app}"
APP_VERSION="${APP_VERSION:-${GITHUB_REF_NAME:-0.0.0}}"
APP_VERSION="${APP_VERSION#v}"
APP_BUILD="${APP_BUILD:-${GITHUB_RUN_NUMBER:-1}}"
MIN_SYSTEM_VERSION="${MIN_SYSTEM_VERSION:-14.0}"
MICROPHONE_USAGE_DESCRIPTION="${MICROPHONE_USAGE_DESCRIPTION:-Type4Me 需要访问麦克风以录制语音并将其转换为文本。}"
APPLE_EVENTS_USAGE_DESCRIPTION="${APPLE_EVENTS_USAGE_DESCRIPTION:-Type4Me 需要辅助功能权限来注入转写文字到其他应用}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_DIR/dist}"
APP_PATH="${APP_PATH:-$OUTPUT_DIR/$APP_NAME.app}"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
SIGN_APP="${SIGN_APP:-1}"

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    SIGNING_IDENTITY="$CODESIGN_IDENTITY"
elif [ "$SIGN_APP" = "1" ] && security find-identity -v -p codesigning 2>/dev/null | grep -q "Type4Me Dev"; then
    SIGNING_IDENTITY="Type4Me Dev"
elif [ "$SIGN_APP" = "1" ]; then
    SIGNING_IDENTITY="-"
else
    SIGNING_IDENTITY=""
fi

echo "Building universal $BUILD_CONFIGURATION binary..."
if ! xcrun swift build \
    -c "$BUILD_CONFIGURATION" \
    --package-path "$PROJECT_DIR" \
    --arch arm64 \
    --arch x86_64
then
    echo "Universal build unavailable on this runner, falling back to native architecture..."
    xcrun swift build \
        -c "$BUILD_CONFIGURATION" \
        --package-path "$PROJECT_DIR"
fi

if [ -f "$PROJECT_DIR/.build/apple/Products/Release/Type4Me" ]; then
    BINARY="$PROJECT_DIR/.build/apple/Products/Release/Type4Me"
elif [ -f "$PROJECT_DIR/.build/release/Type4Me" ]; then
    BINARY="$PROJECT_DIR/.build/release/Type4Me"
else
    BINARY="$(find "$PROJECT_DIR/.build" -path '*/release/Type4Me' -type f -not -path '*/x86_64/*' -not -path '*/arm64/*' | head -n 1)"
fi

if [ ! -f "$BINARY" ]; then
    echo "Build failed: binary not found"
    exit 1
fi

echo "Packaging app bundle at $APP_PATH..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$APP_PATH/Contents/Resources/Sounds"

cp "$BINARY" "$APP_PATH/Contents/MacOS/$APP_EXECUTABLE"
cp "$PROJECT_DIR/Type4Me/Resources/${APP_ICON_NAME}.icns" "$APP_PATH/Contents/Resources/${APP_ICON_NAME}.icns"
cp "$PROJECT_DIR/Type4Me/Resources/Sounds/"*.wav "$APP_PATH/Contents/Resources/Sounds/"

cat >"$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_EXECUTABLE}</string>
    <key>CFBundleIconFile</key>
    <string>${APP_ICON_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${APP_BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_SYSTEM_VERSION}</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>${MICROPHONE_USAGE_DESCRIPTION}</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>${APPLE_EVENTS_USAGE_DESCRIPTION}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "Signing app bundle with '$SIGNING_IDENTITY'..."
    codesign -f -s "$SIGNING_IDENTITY" "$APP_PATH"
else
    echo "Skipping codesign because SIGN_APP=$SIGN_APP"
fi

echo "Packaged app bundle: $APP_PATH"
