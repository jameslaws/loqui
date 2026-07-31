#!/bin/bash
# Build a signed + notarized + stapled loqui.dmg for public download.
#
# One-time setup: create an app-specific password at appleid.apple.com, then:
#   xcrun notarytool store-credentials loqui-notary \
#     --apple-id <your-apple-id> --team-id <your-team-id> --password <app-specific-pw>
#
# Maintainer-only: publishing a signed build needs a paid Apple Developer
# account. To just build and run Loqui yourself, use ./install.sh instead.
set -euo pipefail
cd "$(dirname "$0")"

# Overridable so a fork can sign and publish under its own identity/repo.
DEVID="${LOQUI_SIGN_IDENTITY:-Developer ID Application: James Laws (2R6UK9F228)}"
NOTARY_PROFILE="${LOQUI_NOTARY_PROFILE:-loqui-notary}"
GH_REPO="${LOQUI_GH_REPO:-jameslaws/loqui}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/loqui/Resources/Info.plist)
# Assemble OUTSIDE the iCloud-synced project dir — iCloud keeps re-tagging files
# with com.apple.FinderInfo, which codesign refuses to sign.
OUT="$(mktemp -d "${TMPDIR:-/tmp}/loqui-release.XXXXXX")"
APP="$OUT/loqui.app"
DMG="$OUT/loqui-$VERSION.dmg"

notarize() {  # $1 = path to .zip or .dmg
    local out id
    if ! out=$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1); then
        echo "$out"
        id=$(echo "$out" | awk '/id:/{print $2; exit}')
        [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" || true
        echo "❌ notarization failed for $1" >&2
        exit 1
    fi
    echo "$out"
}

echo "==> universal release build (arm64 + x86_64)"
PRODUCTS=".build/apple/Products/Release"

# Info.plist is embedded into the binary via -sectcreate (see Package.swift), but
# SwiftPM doesn't track it as a linker input — bump the version or the feed URL
# and a plain rebuild silently ships the previous plist. Drop the product so the
# link step re-runs. Costs a relink, not a recompile.
rm -f "$PRODUCTS/loqui"

# -file-prefix-map scrubs the absolute project path out of embedded #file strings.
swift build -c release --arch arm64 --arch x86_64 \
    -Xswiftc -file-prefix-map -Xswiftc "$(pwd)=."
BIN="$PRODUCTS/loqui"
FW="$PRODUCTS/Sparkle.framework"
echo "==> assemble $APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/loqui"
cp Sources/loqui/Resources/Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Embed Sparkle (ditto preserves the framework's symlink/version layout).
ditto "$FW" "$APP/Contents/Frameworks/Sparkle.framework"
echo "    archs: $(lipo -archs "$APP/Contents/MacOS/loqui")"

# Strip extended attributes (Finder info / resource forks — e.g. from the
# iCloud-synced Desktop). codesign refuses to sign a bundle that carries them.
xattr -cr "$APP"

echo "==> sign Sparkle nested code inner-to-outer (required for notarization)"
SPARK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
sign() { codesign --force --options runtime --timestamp --sign "$DEVID" "$@"; }
# XPC services first; Downloader is sandboxed, so keep its existing entitlements.
sign --preserve-metadata=entitlements "$SPARK/XPCServices/Downloader.xpc"
sign "$SPARK/XPCServices/Installer.xpc"
sign "$SPARK/Autoupdate"
sign "$SPARK/Updater.app"
sign "$APP/Contents/Frameworks/Sparkle.framework"

echo "==> sign app (Developer ID + hardened runtime)"
codesign --force --options runtime --timestamp \
    --entitlements loqui.entitlements --sign "$DEVID" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> notarize + staple the app (so first launch works offline)"
ZIP="$OUT/loqui.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
notarize "$ZIP"
xcrun stapler staple "$APP"

echo "==> build styled DMG (clean window, app left / Applications right) from the stapled app"
# Layout is applied via hand-rolled Finder AppleScript on a read-write image, then
# converted to compressed read-only. NO background image: on macOS 26 the Finder
# background-picture command silently aborts the rest of the layout (create-dmg AND
# dmgbuild both failed that way). Without it, the window/size/icon-position commands
# apply cleanly. Order matters: view options + arrangement-off BEFORE positions,
# with delays, or Finder auto-arranges.
STAGE="$OUT/dmg"
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/loqui.app"
ln -s /Applications "$STAGE/Applications"
DMG_RW="$OUT/loqui-rw.dmg"
hdiutil detach "/Volumes/loqui" 2>/dev/null || true   # avoid a "loqui 1" remount
hdiutil create -volname "loqui" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$DMG_RW" >/dev/null
hdiutil attach "$DMG_RW" -noautoopen >/dev/null
sleep 1
osascript <<'OSA'
tell application "Finder"
  tell disk "loqui"
    open
    delay 1
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set pathbar visible of container window to false
    set the bounds of container window to {300, 150, 900, 550}
    delay 1
    set vo to the icon view options of container window
    set arrangement of vo to not arranged
    set icon size of vo to 128
    set text size of vo to 13
    set label position of vo to bottom
    delay 1
    set position of item "loqui.app" of container window to {175, 195}
    set position of item "Applications" of container window to {425, 195}
    delay 1
    update without registering applications
    delay 2
    close
  end tell
end tell
OSA
sync
hdiutil detach "/Volumes/loqui" >/dev/null 2>&1 || hdiutil detach "/Volumes/loqui" -force >/dev/null 2>&1 || true
rm -f "$DMG"
hdiutil convert "$DMG_RW" -format UDZO -o "$DMG" >/dev/null
xattr -cr "$DMG"
codesign --force --timestamp --sign "$DEVID" "$DMG"

echo "==> notarize + staple the DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo ""
echo "   Gatekeeper:"
spctl -a -t open --context context:primary-signature -vvv "$DMG" 2>&1 | head -3 || true

# Generate the Sparkle appcast. generate_appcast reads each DMG's version,
# EdDSA-signs it with the key in the keychain, and writes appcast.xml with
# download URLs built from the prefix.
#
# It applies ONE prefix to every DMG in the directory it scans, but GitHub
# Release asset URLs are per-tag — so scanning a directory that accumulated
# older DMGs would stamp them all with this release's tag and produce dead
# links. Staging a clean directory holding only this build keeps every URL
# correct. A single-item appcast is valid and sufficient: Sparkle offers the
# newest applicable item, so a user on any older version still updates.
echo "==> generate Sparkle appcast"
STAGE_FEED="$OUT/appcast"
mkdir -p "$STAGE_FEED"
cp "$DMG" "$STAGE_FEED/loqui-$VERSION.dmg"
.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
    --download-url-prefix "https://github.com/$GH_REPO/releases/download/v$VERSION/" \
    "$STAGE_FEED"

# The feed is served by GitHub Pages from docs/ on the default branch, which is
# a stable URL that does not change per release. Serving it as a release asset
# instead would tie it to "latest", which silently skips prereleases and drafts
# and would break update checks for everyone the first time you tag one.
mkdir -p docs
cp "$STAGE_FEED/appcast.xml" docs/appcast.xml
mkdir -p build
cp "$DMG" "build/loqui-$VERSION.dmg"

rm -rf "$OUT"
echo ""
echo "✅ Done."
echo "   App DMG:  build/loqui-$VERSION.dmg"
echo "   Appcast:  docs/appcast.xml  (commit this — it is the live feed)"
echo ""
echo "   → Publish, in this order:"
echo ""
echo "     1. gh release create v$VERSION -R $GH_REPO \\"
echo "            build/loqui-$VERSION.dmg \\"
echo "            --title 'Loqui $VERSION' --notes '...'"
echo ""
echo "     2. git add docs/appcast.xml && git commit -m 'Release $VERSION' && git push"
echo ""
echo "   Order matters: the appcast points at the release asset, so publish the"
echo "   release first or the feed briefly advertises a download that 404s."
