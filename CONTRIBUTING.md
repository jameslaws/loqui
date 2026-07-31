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
  (Intel Macs and macOS 15–25 are the thin spots)
- Text-cleanup improvements
- Documentation and accessibility fixes

## Ground rules

- **Nothing may make a network request.** "Nothing leaves your Mac" is the
  product, not a nice-to-have. The only permitted connection is Sparkle's
  existing update check. No analytics, no crash reporting, no remote config.
- **No new dependencies** without discussing it first. Sparkle is the only one,
  and it earns its place.
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

## Pull requests

- One logical change per PR, with a description of what and why.
- Say which macOS version and hardware you tested on.
- Keep commits readable; squash noise before opening.

Please note that merged code ships in a build **signed with my Apple Developer
ID and notarized under my name**. That means I review contributions closely,
particularly anything touching input handling, file writes, or the update path.
It's nothing personal — it's what that signature obligates me to do.

## Security

Do not report vulnerabilities through a pull request or public issue. See
[SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the same
license as this project. See [LICENSE](LICENSE).
