#!/usr/bin/env bash
# Builds ShotMate.app and packages it as build/ShotMate.dmg (drag-to-Applications installer).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="$ROOT/build/dmg"
DMG="$ROOT/build/ShotMate.dmg"

"$ROOT/Scripts/build-app.sh" release

echo "→ Creating disk image…"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$ROOT/build/ShotMate.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "ShotMate" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"
hdiutil verify "$DMG" >/dev/null

echo "✓ Built $DMG"
