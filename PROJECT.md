---
playbook: v5.2.2
skills: [core, crew, planning, testing, code-standards, checkpoint, shipping, stack-guide, access, accessibility, design-slot, playbook]
access: public             # anyone downloads it, no account
design: proposed-in-plan   # Mac: BRAND.md. Windows: windows/design/tokens.json (approved in plans/windows-groundwork)
staging: https://github.com/jameslaws/loqui/releases?q=windows-v&expanded=true   # Windows test channel: each staging merge's test version (pre-releases)
production: https://github.com/jameslaws/loqui/releases/latest
signed_in_page: /          # no sign-in: Loqui has no server and no accounts
branches:
  staging: staging
  production: main
---

# Loqui

Dictation that stays on your computer: press a shortcut, speak, and clean text appears wherever your cursor is. Transcription runs on the device, so your voice never leaves it. The Mac app ships today. The Windows app (Windows 11 on Intel, AMD and Arm) is built (`plans/windows-version`): teammates use it from the test channel, and it goes public when James presses Ship.

## Who it's for

Public. Anyone can download Loqui from GitHub with no account, no subscription and no sign-up. There is no server, so sign-up will never be needed.

## Stack

- **Mac:** a Swift package (`Package.swift`, `Sources/loqui`), SwiftUI and AppKit, Apple's on-device speech (SpeechAnalyzer on macOS 26, SFSpeechRecognizer before), Sparkle for updates. Tests use Swift Testing.
- **Windows** (`windows/`): Tauri 2. The parts that talk to Windows are Rust, pinned in `windows/rust-toolchain.toml`; the windows you look at are React, Vite and TypeScript; pnpm, Biome and Vitest, with exact versions and committed lockfiles. `windows/crates/loqui-core` holds the rules and file formats in plain Rust that builds and tests on any computer. The look is `windows/design/tokens.json`; screens use only those tokens. Speech becomes text on the PC through sherpa-onnx (v2.0.1, `windows/crates/loqui-speech`) running NVIDIA's open Parakeet TDT 0.6B v3 model; the engine and the 640 MB model are downloaded at build time by `pnpm fetch:speech`, checked against pinned SHA-256s, and packed into the installer. They never go in git.
- **Why Tauri for Windows:** the stack guide has no Windows default. The screens can be built and checked on the Mini with no Windows PC, signed automatic updates come built in, and an open-source dictation app (Handy) already ships this way. A bare Tauri window was measured to open no internet connections, so the privacy promise holds.
- **Shared:** `shared/cleanup-cases.json` writes the cleanup rules down as examples. The Mac (`swift test`) and the Windows core (`cargo test`) must both pass every one.

## Where it runs

On people's own computers. Nothing runs on the Mini or the droplet.

- **Staging:** the `staging` branch; pull requests merge there. Mac: a local build (`./install.sh`). Windows: the test channel. Every merge into `staging` that changes `windows/` becomes a test version: a GitHub pre-release `windows-v<version>-test` (never "latest") with the full and update installers for Intel/AMD and Arm, and the test update list, `beta.json` on the fixed pre-release `windows-test-feed`, points at it. A PC with "Get test versions" on in Settings gets each one by itself.
- **Production:** Mac: the signed, notarized DMG on GitHub Releases, and the update feed `https://jameslaws.github.io/loqui/appcast.xml` on GitHub Pages from `docs/`. Windows: a promoted version's release `windows-v<version>` (the exact files of its test version, never "latest", so `releases/latest` stays the Mac's) and the public update list `https://jameslaws.github.io/loqui/windows/stable.json` on GitHub Pages from `docs/windows/`. Nothing is public until the ship. The download page (`docs/index.html`, https://jameslaws.github.io/loqui/) offers each visitor their computer's download first, and both with no script or on a phone; its Download for Windows button goes to `docs/windows/download.html`, which starts the current public installer and which Promote rewrites in the same commit as `stable.json`. Until the first Promote it says the Windows download is on its way.
- **Data:** none of ours. Each person's settings, history and logs are local files on their own computer (`cleanup.json`, `history.jsonl` and `dictation-log.jsonl` have the same formats on both).

## How it ships

- **Branches:** feature branches merge into `staging`, which is where test builds come from. Releases come from `main`: `staging` is merged into `main` when a version is ready.
- **Checks on every pull request:** `build.yml` (macOS 26: build, `swift test`, bundle check) and `windows.yml` when `windows/`, `shared/`, the download page or the README, security, roadmap or contributing notes change (the page as Windows, Mac and phone visitors with its accessibility scan, in a browser on Linux; and on both Windows computers: core tests, test build, install, start, screenshots; then real dictations into Notepad through a virtual sound cable on Intel/AMD, and from a sound file on Arm).
- **Mac release:** `./release.sh`, run by hand on James's Mac: universal build, sign, notarize, publish to GitHub Releases, then commit `docs/appcast.xml`. Merging to `staging` or `main` ships nothing to Mac users by itself.
- **Windows release:** built only on GitHub's Windows computers. `windows-release.yml` makes each test version from `staging` (release first, list second; a version that exists is refused). After James presses Ship in Aiva, the Lead runs `windows-promote.yml` from main with the tested version: it publishes the same files (checksums compared, nothing rebuilt) and then commits `docs/windows/stable.json` to main once the Mac build check passes on it. Only the repository's owner can start Promote or Roll back. Updates carry a signature from loqui's Windows update key, a secret only in the `windows-release` environment (James's backup is in 1Password); loqui refuses any update without it. Microsoft signing is built in behind the `WINDOWS_SIGNING` repository variable, off for now: while off, every release opens with how to get past SmartScreen.
- **Going back:** Mac: put the previous release's `docs/appcast.xml` back and push; the previous DMG stays on Releases. Windows: `windows-rollback.yml` with the last good version builds its code again as a new, higher version and promotes it, since installed copies only move forward; every PC gets it on its next check. Promote and Roll back were proved before the ship by `windows-drill.yml` (push a tag `windows-drill-<n>`), on drill versions and drill lists only.
- **Database changes:** none. There is no database.

## Commands

- Mac, in the repo root: `swift build`, `swift test`, `./install.sh` (build and install locally), `./release.sh` (maintainer release).
- Windows, in `windows/`: `pnpm dev` (run the app with live reload), `pnpm check` (format, lint, types, Rust lint and core tests), `pnpm check:changed` (only what your changes touch), `pnpm test:contracts` (shared cleanup examples, settings file, look, project records), `pnpm fetch:speech` (download the speech engine and model, checked; needed before `pnpm build` and `pnpm dev`), `pnpm build` (the full installer and, with an update key in `TAURI_SIGNING_PRIVATE_KEY`, the update installer, into `target/installers`), `pnpm test:acceptance` (Windows only, after `pnpm build`: installs, starts, clicks the tray menu, quits), `pnpm build:test-audio` (Arm checks only: a build that plays a sound file instead of the microphone, never shipped), `pnpm test:e2e` (Windows only, after the acceptance checks: real dictations into Notepad), `pnpm test:install` (Windows only, last: install, update and uninstall, needing this version and the next built as check builds, as `windows.yml` does), `pnpm test:screens` (every window in a browser, with keyboard and accessibility checks), `pnpm test:page` (the download page and the Windows download page, as Windows, Mac and phone visitors, with no script, and their accessibility), `pnpm start` (run the built app).

## Project rules

- Full Windows runs happen on GitHub's Windows computers, never on the Mini: the repo is public so they're free, and the Mini's runner refuses public repos. Rust core tests may run on the Mini.
- `shared/cleanup-cases.json`: add cases freely; changing an existing case's expected output changes what users get, so it needs a `changes.md` entry.
- The Mac app's behaviour doesn't change for Windows work; the Mac side only gains tests.
- `loqui-core` owns all file reading and writing on Windows; screens never touch files. Windows keeps its files under `%LOCALAPPDATA%\Loqui`, never the roaming profile.
- Every Windows version before the ship is 0.0.x; the first public one is 0.1.0, and after it each merge into `staging` that changes `windows/` raises the patch number (a check fails a pull request that doesn't). The version lives in `windows/package.json` only.
- Words for Windows (README, SECURITY.md, release notes, the download pages) say plainly that it isn't signed by Microsoft yet and how to get past SmartScreen, and never claim a publisher, until the `WINDOWS_SIGNING` switch is on.
