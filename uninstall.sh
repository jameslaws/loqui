#!/bin/bash
# Remove Loqui from this Mac.
#
#   ./uninstall.sh            # remove the app, ask before deleting your data
#   ./uninstall.sh --purge    # remove the app and all data, no prompt
#   ./uninstall.sh --keep     # remove the app, keep all data
set -euo pipefail

say() { printf "\033[1m==>\033[0m %s\n" "$1"; }

MODE="ask"
case "${1:-}" in
    --purge) MODE="purge" ;;
    --keep)  MODE="keep" ;;
    "")      ;;
    *)       echo "usage: $0 [--purge|--keep]" >&2; exit 1 ;;
esac

BUNDLE_ID="com.jameslaws.loqui"
SUPPORT="$HOME/Library/Application Support/Loqui"
LOG="$HOME/Library/Logs/LoquiVoiceKey.log"

pkill -x loqui 2>/dev/null && sleep 1 || true

for APP in /Applications/loqui.app "$HOME/Applications/loqui.app"; do
    if [ -e "$APP" ]; then
        say "removing $APP"
        rm -rf "$APP"
    fi
done

# Your dictation history and stats live outside the bundle, so they survive an
# app delete. That's deliberate — but it means an uninstall has to clean up too.
if [ "$MODE" = "ask" ] && [ -d "$SUPPORT" ]; then
    echo
    echo "Your transcription history and dictation stats are stored at:"
    echo "  $SUPPORT"
    read -r -p "Delete them too? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] && MODE="purge" || MODE="keep"
fi

if [ "$MODE" = "purge" ]; then
    say "removing local data"
    rm -rf "$SUPPORT"
    rm -f "$LOG"
    defaults delete "$BUNDLE_ID" 2>/dev/null || true
else
    say "keeping your data at $SUPPORT"
fi

cat <<EOF

✅ Loqui removed.

macOS keeps its permission grants even after an app is deleted. To clear them,
remove "loqui" from System Settings → Privacy & Security → Accessibility
(and → Microphone).
EOF
