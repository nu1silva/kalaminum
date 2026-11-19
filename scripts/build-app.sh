#!/usr/bin/env bash
# Builds build/Kalaminum.app from the Swift package.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

CONFIG="${1:-release}"
swift build -c "$CONFIG" --product Kalaminum 2>&1 | grep -v "ld: warning: search path" || true
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Kalaminum"
[ -x "$BIN" ] || { echo "build failed" >&2; exit 1; }

APP=build/Kalaminum.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Kalaminum"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null   # ad-hoc signature; enough to run locally
echo "Built $APP"
