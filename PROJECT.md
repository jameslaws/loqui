---
playbook: v5.2.2
skills: [core, crew, planning, testing, code-standards, checkpoint, shipping, stack-guide, access, accessibility, design-slot, playbook]
access: public             # anyone downloads it, no account
design: proposed-in-plan   # Mac: BRAND.md. Windows: windows/design/tokens.json (approved in plans/windows-groundwork)
staging: https://github.com/jameslaws/loqui/actions/workflows/windows.yml   # each run's test build (Windows, until step 5)
production: https://github.com/jameslaws/loqui/releases/latest
signed_in_page: /          # no sign-in: Loqui has no server and no accounts
branches:
  staging: main
  production: main
---

# Loqui

Dictation that stays on your computer: press a shortcut, speak, and clean text appears wherever your cursor is. Transcription runs on the device, so your voice never leaves it. The Mac app ships today; the Windows app is being built in six steps (`plans/windows-*`).

## Who it's for

Public. Anyone can download Loqui from GitHub with no account, no subscription and no sign-up. There is no server, so sign-up will never be needed.

## Stack

- **Mac:** a Swift package (`Package.swift`, `Sources/loqui`), SwiftUI and AppKit, Apple's on-device speech (SpeechAnalyzer on macOS 26, SFSpeechRecognizer before), Sparkle for updates. Tests use Swift Testing.
- **Windows** (`windows/`): Tauri 2. The parts that talk to Windows are Rust, pinned in `windows/rust-toolchain.toml`; the windows you look at are React, Vite and TypeScript; pnpm, Biome and Vitest, with exact versions and committed lockfiles. `windows/crates/loqui-core` holds the rules and file formats in plain Rust that builds and tests on any computer. The look is `windows/design/tokens.json`; screens use only those tokens.
- **Why Tauri for Windows:** the stack guide has no Windows default. The screens can be built and checked on the Mini with no Windows PC, signed automatic updates come built in, and an open-source dictation app (Handy) already ships this way. A bare Tauri window was measured to open no internet connections, so the privacy promise holds.
- **Shared:** `shared/cleanup-cases.json` writes the cleanup rules down as examples. The Mac (`swift test`) and the Windows core (`cargo test`) must both pass every one.

## Where it runs

On people's own computers. Nothing runs on the Mini or the droplet.

- **Staging:** Mac: a local build (`./install.sh`). Windows, until step 5: the unsigned test build attached to each run of the Windows check on GitHub, built and started on GitHub's `windows-latest` (Intel/AMD) and `windows-11-arm` computers. Step 5 replaces this with a test channel.
- **Production:** Mac: the signed, notarized DMG on GitHub Releases, and the update feed `https://jameslaws.github.io/loqui/appcast.xml` on GitHub Pages from `docs/`. Windows: nothing public until step 6.
- **Data:** none of ours. Each person's settings, history and logs are local files on their own computer (`cleanup.json` has the same format on both).

## How it ships

- **Checks on every pull request:** `build.yml` (macOS 26: build, `swift test`, bundle check) and `windows.yml` when `windows/` or `shared/` change (both Windows computers: core tests, test build, install, start, screenshots).
- **Mac release:** `./release.sh`, run by hand on James's Mac: universal build, sign, notarize, publish to GitHub Releases, then commit `docs/appcast.xml`. Merging to main ships nothing to Mac users.
- **Going back:** Mac: put the previous release's `docs/appcast.xml` back and push; the previous DMG stays on Releases. Windows test builds: download an earlier run's build.
- **Database changes:** none. There is no database.

## Commands

- Mac, in the repo root: `swift build`, `swift test`, `./install.sh` (build and install locally), `./release.sh` (maintainer release).
- Windows, in `windows/`: `pnpm dev` (run the app with live reload), `pnpm check` (format, lint, types, Rust lint and core tests), `pnpm check:changed` (only what your changes touch), `pnpm test:contracts` (shared cleanup examples, settings file, look, project records), `pnpm build` (the test installer), `pnpm test:acceptance` (Windows only, after `pnpm build`: installs, starts, clicks the tray menu, quits), `pnpm start` (run the built app).

## Project rules

- Full Windows runs happen on GitHub's Windows computers, never on the Mini: the repo is public so they're free, and the Mini's runner refuses public repos. Rust core tests may run on the Mini.
- `shared/cleanup-cases.json`: add cases freely; changing an existing case's expected output changes what users get, so it needs a `changes.md` entry.
- The Mac app's behaviour doesn't change for Windows work; the Mac side only gains tests.
- `loqui-core` owns all file reading and writing on Windows; screens never touch files. Windows keeps its files under `%LOCALAPPDATA%\Loqui`, never the roaming profile.
- Every Windows version before launch is 0.0.x; step 6 makes the first public one 0.1.0. The version lives in `windows/package.json` only.
