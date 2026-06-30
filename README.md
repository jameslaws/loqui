# loqui

A quiet macOS menu-bar dictation app. Press a shortcut, speak, and clean text
appears wherever your cursor is — transcribed **100% on-device**. No server, no
account, nothing leaves your Mac.

By James Laws. Distributed free as a signed, notarized,
auto-updating direct download — not the Mac App Store.

## Features
- On-device transcription (Apple SpeechAnalyzer on macOS 26+, SFSpeechRecognizer fallback)
- One configurable global shortcut — tap to toggle, or hold for push-to-talk
- Auto-paste at the cursor + clipboard fallback
- On-device cleanup: filler removal, capitalization, punctuation, a custom spelling dictionary
- Transcription history (local, retention you control) + a menu "Recent" list
- Dictation stats
- Auto-update via Sparkle

## Build & run (dev)
```sh
./make-app.sh        # swift build → assemble + sign /Applications/loqui.app → launch
```
New bundle id ⇒ a one-time TCC re-grant (Accessibility, then Mic/Speech on first dictation).

## Release (signed + notarized + auto-update feed)
```sh
./release.sh         # universal build → Developer ID sign (incl. Sparkle framework)
                     # → notarize + staple app & DMG → generate appcast
```
Output in `build/updates/` (DMG + `appcast.xml`). Upload both to
`https://jameslaws.com/loqui/`. One-time notarytool setup: see the header of `release.sh`.

## Requirements
- macOS 26+ officially (runs back to 15 via the fallback engine, unverified)
- Apple Silicon or Intel (universal build)

## Key docs

- `BRAND.md` — identity (icon, color, wordmark)
- `ROADMAP.md` — what's next
