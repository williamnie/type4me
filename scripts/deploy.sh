#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${APP_PATH:-/Applications/Type4Me.app}"
APP_NAME="Type4Me"
APP_VERSION="${APP_VERSION:-1.2.4}"
APP_BUILD="${APP_BUILD:-1}"
LAUNCH_APP="${LAUNCH_APP:-1}"

echo "Stopping Type4Me..."
osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
sleep 1

echo "Deploying to $APP_PATH..."
APP_PATH="$APP_PATH" \
APP_VERSION="$APP_VERSION" \
APP_BUILD="$APP_BUILD" \
bash "$PROJECT_DIR/scripts/package_app.sh"

if [ "$LAUNCH_APP" = "1" ]; then
    echo "Launching via GUI session (no shell env vars)..."
    launchctl asuser "$(id -u)" /usr/bin/open "$APP_PATH"
else
    echo "Skipping launch because LAUNCH_APP=$LAUNCH_APP"
fi

echo "Done."
