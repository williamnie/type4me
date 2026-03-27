#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${APP_NAME:-Type4Me}"
APP_VERSION="${APP_VERSION:-0.0.0}"
APP_PATH="${APP_PATH:-$PROJECT_DIR/dist/$APP_NAME.app}"
DMG_PATH="${DMG_PATH:-$PROJECT_DIR/dist/${APP_NAME}-v${APP_VERSION}.dmg}"
VOLUME_NAME="${VOLUME_NAME:-$APP_NAME}"

if [ ! -d "$APP_PATH" ]; then
    echo "App bundle not found at $APP_PATH"
    exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${APP_NAME}.dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
mkdir -p "$(dirname "$DMG_PATH")"

echo "Creating disk image at $DMG_PATH..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "Packaged disk image: $DMG_PATH"
