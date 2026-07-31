# Security Policy

Loqui runs with Accessibility and Microphone access on people's machines, so
security reports are taken seriously and handled promptly.

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

Helpful things to include: the macOS version, the Loqui version (menu → About),
what an attacker gains, and steps to reproduce.

## Scope

Especially interested in:

- Anything that lets the event tap capture, store, or leak keystrokes beyond the
  configured shortcut
- Any path where transcribed text or audio leaves the machine
- Weaknesses in the Sparkle update chain — feed handling, signature validation,
  or the ability to get an unsigned or attacker-supplied update installed
- Local privilege or sandbox-escape issues arising from the app's entitlements
- Exposure of `history.jsonl` to other users or processes on a shared Mac

Out of scope:

- The fact that Loqui requires Accessibility. It's inherent to a global-shortcut
  dictation app and is documented in the README's security model.
- The fact that `history.jsonl` is plain text in your own user-owned Application
  Support directory, protected by macOS file permissions. Retention is
  configurable and can be turned off entirely.
- Vulnerabilities in macOS itself or in Apple's speech frameworks — report those
  to Apple.

## Supported versions

Loqui ships as a rolling release. Only the latest version gets security fixes.
Update via Sparkle, or re-run `./install.sh` if you built from source.
