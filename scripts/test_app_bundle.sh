#!/bin/bash
set -euo pipefail

APP_PATH="${1:-${APP_PATH:-/Applications/Type4Me.app}}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXPECTED_EXECUTABLE="${EXPECTED_EXECUTABLE:-Type4Me}"
EXPECTED_BUNDLE_ID="${EXPECTED_BUNDLE_ID:-com.type4me.app}"
EXPECTED_APP_NAME="${EXPECTED_APP_NAME:-Type4Me}"
EXPECTED_ICON_FILE="${EXPECTED_ICON_FILE:-AppIcon}"
EXPECTED_MIN_SYSTEM_VERSION="${EXPECTED_MIN_SYSTEM_VERSION:-14.0}"
EXPECTED_LSUIELEMENT="${EXPECTED_LSUIELEMENT:-true}"
EXPECTED_VERSION="${EXPECTED_VERSION:-}"
EXPECTED_BUILD="${EXPECTED_BUILD:-}"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

read_plist() {
    local key="$1"
    /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null
}

[ -d "$APP_PATH" ] || fail "app bundle not found at $APP_PATH"
[ -f "$INFO_PLIST" ] || fail "Info.plist missing at $INFO_PLIST"
[ -f "$APP_PATH/Contents/MacOS/Type4Me" ] || fail "app executable missing"
[ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ] || fail "app icon missing"

[ "$(read_plist CFBundleExecutable)" = "$EXPECTED_EXECUTABLE" ] || fail "CFBundleExecutable should be $EXPECTED_EXECUTABLE"
[ "$(read_plist CFBundleIdentifier)" = "$EXPECTED_BUNDLE_ID" ] || fail "CFBundleIdentifier should be $EXPECTED_BUNDLE_ID"
[ "$(read_plist CFBundleName)" = "$EXPECTED_APP_NAME" ] || fail "CFBundleName should be $EXPECTED_APP_NAME"
[ "$(read_plist CFBundleDisplayName)" = "$EXPECTED_APP_NAME" ] || fail "CFBundleDisplayName should be $EXPECTED_APP_NAME"
[ "$(read_plist CFBundlePackageType)" = "APPL" ] || fail "CFBundlePackageType should be APPL"
[ -z "$EXPECTED_VERSION" ] || [ "$(read_plist CFBundleShortVersionString)" = "$EXPECTED_VERSION" ] || fail "CFBundleShortVersionString should be $EXPECTED_VERSION"
[ -z "$EXPECTED_BUILD" ] || [ "$(read_plist CFBundleVersion)" = "$EXPECTED_BUILD" ] || fail "CFBundleVersion should be $EXPECTED_BUILD"
[ "$(read_plist CFBundleIconFile)" = "$EXPECTED_ICON_FILE" ] || fail "CFBundleIconFile should be $EXPECTED_ICON_FILE"
[ "$(read_plist LSMinimumSystemVersion)" = "$EXPECTED_MIN_SYSTEM_VERSION" ] || fail "LSMinimumSystemVersion should be $EXPECTED_MIN_SYSTEM_VERSION"
[ -n "$(read_plist NSMicrophoneUsageDescription)" ] || fail "NSMicrophoneUsageDescription should be present"
[ -n "$(read_plist NSAppleEventsUsageDescription)" ] || fail "NSAppleEventsUsageDescription should be present"
[ "$(read_plist LSUIElement)" = "$EXPECTED_LSUIELEMENT" ] || fail "LSUIElement should be $EXPECTED_LSUIELEMENT"

echo "PASS: app bundle metadata looks correct"
