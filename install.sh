#!/bin/bash
# Build and install Loqui from source. No Apple Developer account required.
#
#   ./install.sh
#
# Builds a release binary, assembles a real .app bundle, ad-hoc signs it, and
# installs it to /Applications (falling back to ~/Applications). A real bundle
# is required — not a bare binary — because macOS TCC identifies the process by
# bundle id, so the global shortcut (Accessibility), Microphone, and Speech
# grants only stick for a signed bundle with a stable identity.
set -euo pipefail
cd "$(dirname "$0")"

say()  { printf "\033[1m==>\033[0m %s\n" "$1"; }
warn() { printf "\033[33m!\033[0m  %s\n" "$1"; }
die()  { printf "\033[31m✗\033[0m  %s\n" "$1" >&2; exit 1; }

# ---------------------------------------------------------------- preflight --
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [ "$MAJOR" -lt 15 ]; then
    die "Loqui needs macOS 15 or later (you're on $(sw_vers -productVersion))."
fi
if [ "$MAJOR" -lt 26 ]; then
    warn "macOS 26+ uses Apple's newer on-device speech engine. On $(sw_vers -productVersion)"
    warn "Loqui falls back to the older recognizer — it works, but is less accurate."
fi

command -v swift >/dev/null 2>&1 || die \
"Swift toolchain not found. Install Xcode from the App Store (or the Command Line
    Tools with 'xcode-select --install'), then run this again."

# SwiftPM needs a full SDK to build an AppKit/SwiftUI app; the bare CLT path
# usually works, but Xcode's is the supported one. Only warn — don't block.
if ! xcode-select -p >/dev/null 2>&1; then
    die "No developer directory set. Run 'xcode-select --install' and try again."
fi

# ------------------------------------------------------------------- build ---
say "building loqui (release) — first run downloads Sparkle and takes a few minutes"

# Info.plist is embedded into the binary via -sectcreate (see Package.swift), but
# SwiftPM doesn't know it's a linker input, so editing the plist alone never
# triggers a relink and the binary keeps embedding a stale copy. Dropping the
# product forces a relink; it costs a couple of seconds, not a recompile.
BIN_DIR=$(swift build -c release --show-bin-path)
rm -f "$BIN_DIR/loqui"

swift build -c release
[ -x "$BIN_DIR/loqui" ] || die "build finished but no binary at $BIN_DIR/loqui"
[ -d "$BIN_DIR/Sparkle.framework" ] || die "Sparkle.framework missing from $BIN_DIR"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/loqui/Resources/Info.plist)

# ---------------------------------------------------------------- assemble ---
# Assemble in a temp dir and move into place at the end, so a failure part-way
# through never leaves a half-written app in /Applications.
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/loqui-install.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/loqui.app"

say "assembling loqui.app ($VERSION, $(uname -m))"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/loqui" "$APP/Contents/MacOS/loqui"
cp Sources/loqui/Resources/Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

# Sparkle's auto-update feed serves the official Developer ID-signed build. This
# copy is ad-hoc signed, so Sparkle would refuse to install that update and just
# nag forever. Turn automatic checks off for source builds — re-run install.sh
# (or download the signed release) to update.
/usr/libexec/PlistBuddy -c "Set :SUEnableAutomaticChecks false" "$APP/Contents/Info.plist" >/dev/null

# ------------------------------------------------------------------- sign ----
# Prefer a real signing identity if this machine happens to have one: TCC grants
# survive rebuilds under a stable identity, but an ad-hoc signature changes with
# the binary, so macOS re-asks for Accessibility/Microphone after each rebuild.
# Ad-hoc is the default and needs no Apple Developer account.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Developer ID Application|Apple Development/ {print $2; exit}' || true)
if [ -n "$IDENTITY" ]; then
    say "signing with '$IDENTITY'"
else
    IDENTITY="-"
    say "ad-hoc signing (no Developer ID needed)"
fi

# Strip extended attributes first — files under an iCloud-synced folder carry
# com.apple.FinderInfo, which codesign refuses to sign.
xattr -cr "$APP"
codesign --force --deep --sign "$IDENTITY" "$APP" 2>/dev/null \
    || die "code signing failed — try 'xattr -cr .' in this directory and re-run"
codesign --verify --deep "$APP" || die "signature verification failed"

# ---------------------------------------------------------------- install ----
DEST="/Applications"
if [ ! -w "$DEST" ]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
    warn "/Applications isn't writable — installing to $DEST instead"
fi
TARGET="$DEST/loqui.app"

# A running copy would shadow the relaunch and keep the old bundle busy.
pkill -x loqui 2>/dev/null && sleep 1 || true

if [ -e "$TARGET" ]; then
    say "replacing existing $TARGET"
    rm -rf "$TARGET"
fi
mv "$APP" "$TARGET"

say "launching"
open "$TARGET"

cat <<EOF

✅ Installed: $TARGET

Loqui lives in the menu bar — look for the microphone glyph at the top right.

macOS will ask for two permissions the first time:
  1. Accessibility  — needed to watch for your shortcut key and paste at the cursor
  2. Microphone     — needed to hear you (transcription itself is 100% on-device)

If the shortcut doesn't respond, grant Accessibility manually at
System Settings → Privacy & Security → Accessibility, then toggle loqui off/on.

Auto-updates are disabled for source builds. Re-run ./install.sh to update.
To remove Loqui completely, run ./uninstall.sh
EOF
