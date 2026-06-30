#!/bin/bash
# Assemble + sign /Applications/loqui.app from an already-built loqui binary.
#
# Why a real bundle (not the bare SPM binary): TCC identifies the process by
# bundle id, so the global voice key (F5/⌘R event tap), Microphone, and Speech
# grants only stick for a signed bundle with a stable identity. A bare binary
# gets re-prompted every rebuild and path-based grants never match.
set -euo pipefail
cd "$(dirname "$0")"

PRODUCTS_DIR="${1:?usage: assemble-app.sh <dir containing the built loqui binary>}"
APP="/Applications/loqui.app"

IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
if [ -z "$IDENTITY" ]; then
    echo "no Apple Development signing identity found" >&2
    exit 1
fi

# A still-running copy would shadow the relaunch.
pkill -x loqui 2>/dev/null && sleep 1 || true

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$PRODUCTS_DIR/loqui" "$APP/Contents/MacOS/loqui"
cp Sources/loqui/Resources/Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Embed Sparkle so the linked framework resolves at launch (dogfood only —
# release.sh does the proper inner-to-outer Developer ID signing).
ditto "$PRODUCTS_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

# Strip xattrs (iCloud-synced Desktop tags files with com.apple.FinderInfo,
# which codesign refuses). Then --deep ad-hoc sign for local dogfood.
xattr -cr "$APP"
codesign --force --deep --sign "$IDENTITY" "$APP"
echo "assembled + signed $APP (from $PRODUCTS_DIR)"
