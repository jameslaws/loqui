# Loqui — Roadmap

> What's in the app today and what's being looked at next. Loqui is free, and the
> features it has now stay free.

## Shipped

- On-device dictation with a configurable global shortcut — tap to toggle or hold for push-to-talk
- Auto-paste at the cursor, with a clipboard fallback
- On-device cleanup: filler-word removal, capitalization, punctuation, custom spelling dictionary
- Transcription history with configurable retention, plus a Recent menu
- Dictation stats — words, pace, time saved
- Auto-update via Sparkle, signed and notarized

## Being looked at

- **Verifying the macOS 15–25 fallback engine on real hardware.** Loqui uses Apple's
  SpeechAnalyzer on macOS 26+ and falls back to SFSpeechRecognizer below that. The
  fallback is verified by code but hasn't been exercised on a pre-26 Mac — if you're
  running one, a report either way is genuinely useful.
- **Intel testing.** Releases are universal binaries, but they're developed and tested
  on Apple Silicon.
- **Stability in the event tap and audio pipeline** — the two places where bugs are
  most likely and most annoying.

## Not planned

- **Cloud transcription, accounts, or a server.** On-device is the product, not a
  configuration choice.
- **Telemetry or analytics of any kind**, including anonymous usage stats.

A separate paid companion app may exist at some point. If it does, it will be
additive and Loqui itself will stay free, with everything it does today intact —
nobody's existing app is going to turn into a paywall.
