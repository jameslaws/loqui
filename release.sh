#!/bin/bash
# Build a signed + notarized + stapled loqui.dmg for public download.
#
# One-time setup: create an app-specific password at appleid.apple.com, then:
#   xcrun notarytool store-credentials loqui-notary \
#     --apple-id <your-apple-id> --team-id 2R6UK9F228 --password <app-specific-pw>
set -euo pipefail
cd "$(dirname "$0")"

DEVID="Developer ID Application: James Laws (2R6UK9F228)"
NOTARY_PROFILE="loqui-notary"
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
# -file-prefix-map scrubs the absolute project path out of embedded #file strings.
swift build -c release --arch arm64 --arch x86_64 \
    -Xswiftc -file-prefix-map -Xswiftc "$(pwd)=."

PRODUCTS=".build/apple/Products/Release"
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

echo "==> build + sign DMG from the stapled app"
STAGE="$OUT/dmg"
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "loqui" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
xattr -cr "$DMG"
codesign --force --timestamp --sign "$DEVID" "$DMG"

echo "==> notarize + staple the DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo ""
echo "   Gatekeeper:"
spctl -a -t open --context context:primary-signature -vvv "$DMG" 2>&1 | head -3 || true

# Stage the DMG + generate the Sparkle appcast. generate_appcast reads each
# DMG's version, EdDSA-signs it with the key in the keychain, and writes
# appcast.xml with download URLs under the prefix. Upload BOTH files (plus the
# DMG) to https://jameslaws.com/loqui/.
echo "==> generate Sparkle appcast"
UPDATES="build/updates"
mkdir -p "$UPDATES"
cp "$DMG" "$UPDATES/loqui-$VERSION.dmg"
.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
    --download-url-prefix "https://jameslaws.com/loqui/" \
    "$UPDATES"

rm -rf "$OUT"
echo ""
echo "✅ Done."
echo "   App DMG:  build/updates/loqui-$VERSION.dmg"
echo "   Appcast:  build/updates/appcast.xml"
echo "   → Upload everything in build/updates/ to https://jameslaws.com/loqui/"
