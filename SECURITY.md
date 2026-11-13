# Security Policy

Loqui runs with Accessibility and Microphone access on people's Macs, and watches
the keyboard for its shortcut on people's Windows PCs, so security reports are
taken seriously and handled promptly.

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Use GitHub's private reporting instead:
**[Report a vulnerability](https://github.com/jameslaws/loqui/security/advisories/new)**
(Security tab → Report a vulnerability). That opens a private thread visible only
to the maintainer.

What to expect:

- **Acknowledgement within 3 days.**
- An assessment and a fix plan within 14 days for anything confirmed.
- Credit in the release notes when the fix ships, unless you'd rather not be named.

Helpful things to include: the macOS or Windows version (on Windows, from
**Settings → System → About**, such as "Windows 11 24H2", and whether the PC is
Intel/AMD or Arm), the Loqui version (menu → About; on Windows, the menu by the
clock → About loqui), what an attacker gains, and steps to reproduce.

## Scope

Especially interested in:

- Anything that lets the event tap capture, store, or leak keystrokes beyond the
  configured shortcut
- Any path where transcribed text or audio leaves the machine
- Weaknesses in the Sparkle update chain — feed handling, signature validation,
  or the ability to get an unsigned or attacker-supplied update installed
- Local privilege or sandbox-escape issues arising from the app's entitlements
- Exposure of `history.jsonl` to other users or processes on a shared Mac

On Windows, also:

- The keyboard watcher (the `WH_KEYBOARD_LL` hook): anything that lets it
  capture, store or leak keystrokes beyond the configured shortcut, or that
  makes loqui act on keys that aren't the shortcut
- The Windows update chain: the update lists (`windows/stable.json` on GitHub
  Pages and the test list on the `windows-test-feed` release), the update
  signature check, or any way to get an update installed that wasn't signed with
  loqui's Windows update key, or to move a PC to an older version
- The clipboard: dictated text reaching Windows' clipboard history or cloud
  clipboard sync, or being pasted somewhere other than the window you were in
- Exposure of `%LOCALAPPDATA%\Loqui` (history, dictionary, stats and logs) to
  other users on a shared PC, or anything there leaving the PC

Out of scope:

- The fact that Loqui requires Accessibility. It's inherent to a global-shortcut
  dictation app and is documented in the README's security model.
- The fact that `history.jsonl` is plain text in your own user-owned Application
  Support directory, protected by macOS file permissions. Retention is
  configurable and can be turned off entirely.
- Vulnerabilities in macOS itself or in Apple's speech frameworks — report those
  to Apple.
- On Windows, that loqui isn't signed by Microsoft yet and SmartScreen warns
  about it. That's known and documented in the README; turning signing on is a
  matter of time, not a fix. Vulnerabilities in Windows, WebView2 or the speech
  engine's own code belong with Microsoft or that project.

## Supported versions

Loqui ships as a rolling release. Only the latest version gets security fixes.
Update via Sparkle, or re-run `./install.sh` if you built from source. On
Windows, only the latest public version gets fixes; loqui updates itself, or
choose Check for updates in its menu by the clock.
