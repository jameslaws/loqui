# Contributing to Loqui

Thanks for taking an interest. A few things are worth knowing before you start.

## Before you write code

**Open an issue first for anything non-trivial.** Loqui is deliberately small —
a menu-bar app that does one thing well. Features that add settings, surface
area, or background activity are more likely to be declined than accepted, and
it's better to find that out before you've written it.

Good contributions, in rough order of usefulness:

- Bug fixes, especially in the event tap, audio pipeline, or permission flow
- Compatibility fixes for macOS versions or hardware I can't test on
  (Intel Macs and macOS 15–25 are the thin spots), and on Windows, real PCs
  of every kind: Arm laptops, unusual keyboards and microphones
- Text-cleanup improvements
- Documentation and accessibility fixes

## Ground rules

- **Nothing may make a network request.** "Nothing leaves your computer" is the
  product, not a nice-to-have. The only permitted connections are the existing
  update checks (Sparkle on the Mac, the update lists on Windows). No analytics,
  no crash reporting, no remote config.
- **No new dependencies** without discussing it first. On the Mac, Sparkle is the
  only one, and it earns its place. On Windows, versions are exact and the
  lockfiles are committed.
- **No new entitlements**, and no widening of what the event tap inspects.
- Match the surrounding style. The codebase is plain SwiftUI/AppKit with
  comments that explain *why*, not *what* — keep that up.

## Development

```sh
./make-app.sh     # debug build → install to /Applications → launch
./install.sh      # release build, the path users take
```

There's no Xcode project — it's a SwiftPM package. Open the folder in Xcode or
build from the terminal.

Test on a real machine, not just a build: check that the shortcut still fires
from another app, that text lands at the cursor, and that permissions survive a
relaunch.

## The Windows app

The Windows app is in [`windows/`](windows): Tauri 2, with Rust for the parts
that talk to Windows and React and TypeScript for the windows you see. The rules
and file formats live in `windows/crates/loqui-core`, plain Rust that builds and
tests on any computer. Screens never read or write files; loqui-core does.

You need Node 24, pnpm and Rust through rustup (the version is pinned in
`windows/rust-toolchain.toml`). To run the app itself you need a Windows 11 PC
with [Tauri's prerequisites](https://v2.tauri.app/start/prerequisites/).

```sh
cd windows
pnpm install
pnpm check           # format, lint, types, Rust lint and the core tests (any computer)
pnpm test:contracts  # the shared cleanup examples, settings file and project records
pnpm test:screens    # every window in a browser, with keyboard and accessibility checks
pnpm fetch:speech    # on Windows: the speech engine and model, checked by SHA-256
pnpm dev             # on Windows: run loqui with live reload
pnpm build           # on Windows: the installer
```

**Its full checks run on GitHub's Windows computers**, both the usual Intel/AMD
kind and Arm, on every pull request that touches `windows/` or `shared/`: they
build the installer, install it, start it, dictate into Notepad through a
virtual microphone, photograph every window light and dark, update it and
uninstall it. You don't need a Windows PC for most changes; the pull request's
checks show you the result.

Two rules keep the Mac and Windows apps the same:

- **`shared/cleanup-cases.json` and `shared/stats-cases.json`** write the
  cleanup rules and the stats figures down as examples, and both apps must pass
  every one. Add cases freely; changing an existing case's expected output
  changes what people get, so say so in the pull request.
- **A pull request that changes `windows/` raises the version** in
  `windows/package.json` (0.1.0 to 0.1.1, say). Every change merged that touches
  the Windows app becomes a test version with that number, and a check fails the
  pull request if it doesn't go up.

## Pull requests

- One logical change per PR, with a description of what and why.
- Say which macOS or Windows version and hardware you tested on.
- Keep commits readable; squash noise before opening.

Please note that merged code ships in a build **signed with my Apple Developer
ID and notarized under my name**, and in Windows updates signed with loqui's
update key. That means I review contributions closely, particularly anything
touching input handling (the event tap, the Windows keyboard hook), the
clipboard, file writes, or the update path.
It's nothing personal — it's what that signature obligates me to do.

## Security

Do not report vulnerabilities through a pull request or public issue. See
[SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the same
license as this project. See [LICENSE](LICENSE).
