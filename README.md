# Loqui

A quiet dictation app for Mac and Windows. Press a shortcut, speak, and clean
text appears wherever your cursor is, transcribed **100% on-device**.

No account. No subscription. No server. Your voice never leaves your computer.

## Install

### Mac

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

### Windows

**→ [Download for Windows](https://jameslaws.github.io/loqui/windows/download.html)**
(Windows 11, on Intel, AMD and Arm PCs)

That page starts the right installer for your PC. It installs just for you, with
no administrator needed, puts loqui in Start, and loqui updates itself from there.
The first download is large (about 460 MB) because the speech model comes with
it; updates leave the model alone and are about 10 MB.

**loqui for Windows isn't signed by Microsoft yet.** The first time you run the
installer, Windows shows **"Windows protected your PC"**. Click **More info**,
then **Run anyway**. If Windows' **Smart App Control** is turned on, it blocks
apps that aren't signed and there is no Run anyway, so loqui can't be installed
on that PC for now.

Every installer is also on [the releases page](https://github.com/jameslaws/loqui/releases)
with a `SHA256SUMS.txt` to check it against. To build it yourself, see
[Development](#development).

## Permissions

### Mac

macOS asks for two things the first time you dictate. Both are required, and
neither sends anything anywhere:

| Permission | Why Loqui needs it |
|---|---|
| **Accessibility** | To notice your shortcut key anywhere in the system, and to paste the finished text at your cursor |
| **Microphone** | To hear you. Transcription runs entirely on-device |

If the shortcut doesn't respond, grant Accessibility manually at **System
Settings → Privacy & Security → Accessibility**, then toggle Loqui off and on.

### Windows

Installing asks for nothing. loqui needs only the microphone, and Windows has one
switch for every desktop app: **Settings → Privacy & security → Microphone →
Let desktop apps access your microphone**. loqui's welcome window opens that page
for you and ticks itself off once the switch is on; loqui never changes the
switch itself. If it's off when you dictate, the bubble says so.

Noticing your shortcut and pasting at the cursor need no permission on Windows.
The one thing loqui can't do is type into a program you started as administrator;
there the text stays on the clipboard and the bubble says to press Ctrl+V.

## Features

- On-device transcription — Apple's SpeechAnalyzer on macOS 26+, SFSpeechRecognizer fallback below that.
  On Windows, the [Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) speech
  model through [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx), on the PC itself, in English and
  24 other European languages
- One configurable global shortcut — tap to toggle, or hold for push-to-talk
  (⌘R by default on a Mac, Ctrl+Shift+Space on Windows)
- Auto-paste at the cursor, with a clipboard fallback
- On-device cleanup: filler-word removal, capitalization, punctuation, and a custom spelling dictionary
- Local transcription history with retention you control, plus a menu "Recent" list
- Dictation stats — words, pace, time saved
- Auto-update via [Sparkle](https://sparkle-project.org) on a Mac, and Tauri's signed updater on Windows

## Privacy

The privacy claim is specific, and you can check it against the source:

- **Transcription is on-device.** Loqui uses Apple's local speech frameworks. No
  audio and no text is ever uploaded — there is no server to upload it to.
- **The only network request Loqui ever makes** is Sparkle's update check against
  the appcast at `https://jameslaws.github.io/loqui/appcast.xml`, which is served
  by GitHub Pages from [`docs/`](docs) in this repository — so you can read the
  exact feed your copy is checking. Nothing else in this codebase opens a
  connection; grep for `URLSession` and you'll find zero hits.
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

On Windows the same promises hold, and these are the details:

- **Transcription is on the PC.** The speech model is part of the installer, and
  loqui never downloads anything else.
- **The only network requests loqui for Windows makes are for updates**: once a
  day and when you choose Check for updates, it reads the public update list at
  `https://jameslaws.github.io/loqui/windows/stable.json` (served from
  [`docs/windows/`](docs/windows)), or, if you turned on **Get test versions**,
  the test list at
  `https://github.com/jameslaws/loqui/releases/download/windows-test-feed/beta.json`.
  When you install an update, it downloads it from this repository's GitHub
  releases. While it does either, Windows itself may check that GitHub's
  certificate is still valid. Nothing of yours is sent.
- **Your files stay in `%LOCALAPPDATA%\Loqui`**, never the roaming profile, so
  they don't follow you to other PCs: `history.jsonl` (what you dictated, kept as
  long as you choose, including off), `dictation-log.jsonl` (stats: times, word
  counts and durations, no text), `settings.json` and `cleanup.json` (settings and
  your dictionary), and `logs\voice-key.log` and `logs\cleanup.log` (events and
  word counts, never what you said).
- **The clipboard.** loqui pastes by putting your text on the clipboard and
  pressing Ctrl+V for you. The text stays there afterwards, marked so Windows
  keeps it out of clipboard history and out of clipboard sync to your other
  devices.

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

On Windows:

- **It installs a low-level keyboard hook** (`WH_KEYBOARD_LL`) to notice your
  shortcut anywhere. The hook compares each key to the shortcut you set and acts
  only on that; it does not record, store or forward keystrokes, and a check on
  every change proves that typed keys never reach any loqui file.
- **It needs no administrator rights**, to install, to run or to update. It
  installs to `%LOCALAPPDATA%\Programs\loqui` for your account only.
- **It isn't signed by Microsoft yet**, so it claims no publisher, and Windows
  shows "Windows protected your PC" the first time (More info, then Run anyway).
- **Every update is signed** with loqui's own Windows update key, and loqui
  refuses an update whose signature doesn't match the key built into it. The
  installers are built on GitHub's Windows computers; the key lives only there,
  as a protected secret, and is not in this repository. A version reaches
  everyone only after the maintainer approves it, and a bad one can be rolled
  back.

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

On Windows: **Settings → Apps → Installed apps → loqui → Uninstall**. The
uninstaller asks whether to **also delete your dictation history, dictionary,
settings and stats** (`%LOCALAPPDATA%\Loqui`). Leave it unticked to keep them
for a later reinstall; tick it to remove everything.

## Requirements

- **Mac:** macOS 26 or later for the best engine; runs back to macOS 15 on the
  fallback recognizer. Apple Silicon or Intel.
- **Windows:** Windows 11, on Intel, AMD and Arm (Snapdragon) PCs. No
  administrator rights needed.

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

The Windows app lives in [`windows/`](windows): Tauri 2, with the parts that
talk to Windows in Rust and the windows you see in React and TypeScript. Its
rules and file formats are plain Rust in `windows/crates/loqui-core`, which
builds and tests on any computer, and both apps pass the same cleanup examples in
[`shared/`](shared). To build it yourself on a Windows 11 PC with
[Tauri's prerequisites](https://v2.tauri.app/start/prerequisites/) (the Microsoft
C++ Build Tools and Rust through rustup; the Rust version is pinned in
`windows/rust-toolchain.toml`), Node 24 and pnpm:

```sh
cd windows
pnpm install
pnpm fetch:speech    # the speech engine and model, checked against their SHA-256
pnpm dev             # run loqui with live reload
pnpm build           # the full installer, in windows/target/installers
```

See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

Loqui is free software under the **GNU General Public License v3.0** — see
[LICENSE](LICENSE). You can use it, study it, change it, and share it; if you
distribute a modified version, it has to stay open under the same terms.

Copyright © 2026 James Laws.
