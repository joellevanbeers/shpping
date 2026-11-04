#!/bin/zsh
# Bouwt Shpping.app en zet hem in ~/Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/Shpping.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Shpping "$APP/Contents/MacOS/Shpping"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null

DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x Shpping 2>/dev/null || true
rm -rf "$DEST/Shpping.app"
cp -R "$APP" "$DEST/"
echo "Klaar: $DEST/Shpping.app"
[[ "${1:-}" == "--open" ]] && open "$DEST/Shpping.app"
exit 0
