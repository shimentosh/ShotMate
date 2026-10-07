#!/usr/bin/env bash
# Builds ShotMate.app into ./build.
#
#   Scripts/build-app.sh            # release build
#   Scripts/build-app.sh debug      # debug build
#   ARCHS=arm64 Scripts/build-app.sh   # single architecture (default: universal arm64 + x86_64)
#
# Signing: uses $SHOTMATE_SIGN_IDENTITY if set, otherwise the first "Apple Development"
# identity in the keychain, otherwise ad-hoc. With ad-hoc signing macOS treats every
# rebuild as a new app, so Screen Recording permission must be granted again after
# each rebuild.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
ARCHS="${ARCHS:-arm64 x86_64}"
APP="$ROOT/build/ShotMate.app"
ICONSET="$ROOT/build/AppIcon.iconset"
ICNS="$ROOT/build/AppIcon.icns"

cd "$ROOT"

mkdir -p "$ROOT/build"
SLICES=()
for ARCH in $ARCHS; do
    echo "→ Compiling $ARCH ($CONFIG)…"
    swift build -c "$CONFIG" --arch "$ARCH"
    BIN_DIR="$(swift build -c "$CONFIG" --arch "$ARCH" --show-bin-path)"
    # Each architecture builds into the same folder, so copy the slice out right away.
    cp "$BIN_DIR/ShotMate" "$ROOT/build/ShotMate-$ARCH"
    SLICES+=("$ROOT/build/ShotMate-$ARCH")
done

if [[ ! -f "$ICNS" || "$ROOT/Scripts/make-icon.swift" -nt "$ICNS" ]]; then
    echo "→ Generating app icon…"
    rm -rf "$ICONSET"
    swift "$ROOT/Scripts/make-icon.swift" "$ICONSET"
    iconutil -c icns "$ICONSET" -o "$ICNS"
fi

echo "→ Assembling ShotMate.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/ShotMate"
rm -f "${SLICES[@]}"
cp "$ROOT/ShotMate/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

IDENTITY="${SHOTMATE_SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
    IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ { print $2; exit }')"
fi
IDENTITY="${IDENTITY:--}"

echo "→ Signing with: $([[ "$IDENTITY" == "-" ]] && echo "ad-hoc" || echo "$IDENTITY")"
codesign --force --sign "$IDENTITY" --identifier com.sentosh.ShotMate --timestamp=none "$APP"
codesign --verify --strict "$APP"

echo "✓ Built $APP"
echo "  Run it with: open \"$APP\""
