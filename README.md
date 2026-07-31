# Loqui

A quiet macOS menu-bar dictation app. Press a shortcut, speak, and clean text
appears wherever your cursor is — transcribed **100% on-device**.

No account. No subscription. No server. Your voice never leaves your Mac.

## Install

**Download the app** — the easiest path. Signed and notarized by Apple, so it
just opens:

**→ [Download the latest release](https://github.com/jameslaws/loqui/releases/latest)**

Open the DMG, drag Loqui to Applications, and you're done. It updates itself from
there.

<details>
<summary><b>Or build it from source</b> (no Apple Developer account needed)</summary>

You need macOS 15+ and [Xcode](https://apps.apple.com/us/app/xcode/id497799835)
(free from the App Store). Then:

```sh
git clone https://github.com/jameslaws/loqui.git
cd loqui
./install.sh
```

That builds Loqui, assembles a proper `.app`, signs it ad-hoc, installs it to
`/Applications`, and launches it. No developer account, no certificates, no
Xcode project to open — the script handles everything.

Two things differ from the downloaded build:

- **Auto-updates are off.** The update feed serves the Apple-signed build, which
  won't install over an ad-hoc-signed one. Re-run `./install.sh` to update.
- **Permissions reset when you rebuild.** An ad-hoc signature changes every time
  the binary does, and macOS ties permission grants to that signature — so you'll
  re-approve Accessibility after each rebuild. (If you *do* happen to have an
  Apple Development certificate, `install.sh` uses it automatically and this
  stops happening.)

</details>

## Permissions

macOS asks for two things the first time you dictate. Both are required, and
neither sends anything anywhere:

| Permission | Why Loqui needs it |
|---|---|
| **Accessibility** | To notice your shortcut key anywhere in the system, and to paste the finished text at your cursor |
| **Microphone** | To hear you. Transcription runs entirely on-device |

If the shortcut doesn't respond, grant Accessibility manually at **System
Settings → Privacy & Security → Accessibility**, then toggle Loqui off and on.

## Features

- On-device transcription — Apple's SpeechAnalyzer on macOS 26+, SFSpeechRecognizer fallback below that
- One configurable global shortcut — tap to toggle, or hold for push-to-talk
- Auto-paste at the cursor, with a clipboard fallback
- On-device cleanup: filler-word removal, capitalization, punctuation, and a custom spelling dictionary
- Local transcription history with retention you control, plus a menu "Recent" list
- Dictation stats — words, pace, time saved
- Auto-update via [Sparkle](https://sparkle-project.org)

## Privacy

The privacy claim is specific, and you can check it against the source:

- **Transcription is on-device.** Loqui uses Apple's local speech frameworks. No
  audio and no text is ever uploaded — there is no server to upload it to.
- **The only network request Loqui ever makes** is Sparkle's update check against
  this repository's release feed
  (`https://github.com/jameslaws/loqui/releases/latest/download/appcast.xml`).
  Nothing else in this codebase opens a connection — grep for `URLSession` and
  you'll find zero hits.
- **No analytics, no telemetry, no crash reporting, no account.** Sparkle's
  optional system profiling is off.
- **Your dictated text is stored locally, in plain text**, at
  `~/Library/Application Support/Loqui/history.jsonl` — that's what powers the
  History window and the Recent menu. Retention is yours to set in Settings,
  including **off**, which stops Loqui writing it at all. Deleting history in the
  app deletes it from disk.
- **Stats are separate and contain no text** — just timestamps, word counts, and
  durations, in `dictation-log.jsonl`.
- **Diagnostic logs never contain what you said.** `~/Library/Logs/LoquiVoiceKey.log`
  records events and word counts only.

## Security model

Loqui asks for real power, so here's exactly what it does with it:

- **It installs a `CGEventTap`** to watch for your shortcut key system-wide. The
  tap only inspects key events for a modifier + keycode match against the shortcut
  you configured — it does not record, store, or forward keystrokes. This is what
  the Accessibility permission is for, and it's why a dictation app can't avoid
  asking for it.
- **It is not sandboxed.** A sandboxed app can't install a global event tap or
  paste into another app, which is the entire feature. That's also why Loqui is a
  Developer ID direct download rather than a Mac App Store app.
- **It requests exactly one entitlement**: `com.apple.security.device.audio-input`.
  See [`loqui.entitlements`](loqui.entitlements).
- **Releases are signed with an Apple Developer ID, notarized by Apple, and
  stapled**, and updates are EdDSA-signed through Sparkle. The signing keys are
  not in this repository.

Found a security problem? Please read [SECURITY.md](SECURITY.md) — don't open a
public issue.

## Uninstall

```sh
./uninstall.sh            # removes the app, asks before deleting your data
./uninstall.sh --purge    # removes everything, no prompt
./uninstall.sh --keep     # removes the app, keeps your history and stats
```

If you installed the DMG, drag Loqui to the Trash and delete
`~/Library/Application Support/Loqui`.

## Requirements

- **macOS 26 or later** for the best engine; runs back to macOS 15 on the fallback recognizer
- Apple Silicon or Intel

## Development

```sh
./make-app.sh        # debug build → assemble + sign → install to /Applications → launch
./install.sh         # release build, the same path users take
```

Loqui is a plain SwiftPM package — there's no `.xcodeproj`. Open the folder in
Xcode, or build from the terminal.

Maintainer release path (needs a paid Apple Developer account):

```sh
./release.sh         # universal build → Developer ID sign → notarize + staple → appcast
```

See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

Loqui is free software under the **GNU General Public License v3.0** — see
[LICENSE](LICENSE). You can use it, study it, change it, and share it; if you
distribute a modified version, it has to stay open under the same terms.

Copyright © 2026 James Laws.
