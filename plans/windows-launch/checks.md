# What working means: Windows launch

Plan revision: draft 1 · Approved: not yet

One section per promised outcome. The ID never changes once James has seen it; retire an ID rather than reusing it. The ID's prefix is its area, which CI uses to pick the checks a change affects. Expected behaviour only: results live under `checkpoints/`, never here.

---

### LAUNCH-01: Windows visitors get the Windows download first

- Start: the changed page, opened in Edge on Windows 11 (Playwright with a Windows user agent, and the test machine).
- Action: load the page.
- Result: the main button reads "Download for Windows" and goes to `windows/download.html`; the line under it says Windows 11 on Intel, AMD and Arm and links to the Mac download.
- Checkpoint: 1
- Test: `LAUNCH-01: Windows visitors get the Windows download first`

### LAUNCH-02: Mac visitors see today's page with Windows mentioned

- Start: the changed page in Safari on macOS.
- Action: load the page.
- Result: the main button reads "Download for macOS" and goes where it does today; a link offers the Windows download.
- Checkpoint: 1
- Test: `LAUNCH-02: Mac visitors see today's page with Windows mentioned`

### LAUNCH-03: Without scripts, both downloads show

- Start: the changed page with JavaScript off.
- Action: load the page.
- Result: both buttons are visible and work.
- Checkpoint: 1
- Test: `LAUNCH-03: Without scripts, both downloads show`

### LAUNCH-04: Phones see both, laid out cleanly

- Start: the changed page at 390 × 844.
- Action: load it on iOS Safari and Android Chrome user agents.
- Result: both buttons stacked with "loqui runs on Mac and Windows computers."; nothing overlaps or scrolls sideways.
- Checkpoint: 1
- Test: `LAUNCH-04: Phones see both, laid out cleanly`
- Phone: yes

### LAUNCH-05: The README covers Windows

- Start: README.md on the branch.
- Action: read Install, Permissions, Privacy, Security model, Uninstall, Requirements and Development.
- Result: each has its Windows part: the installer link, Windows' microphone switch, where history, stats and logs live under `%LOCALAPPDATA%\Loqui`, the keyboard watcher acting only on the shortcut, no administrator rights, signing in James's name, both update list addresses as the only network requests, uninstalling with keep or delete, Windows 11 on Intel, AMD and Arm, and building it yourself. The opening line no longer says macOS only.
- Checkpoint: 2
- Test: `LAUNCH-05: The README covers Windows`

### LAUNCH-06: Security policy, roadmap and contributing cover Windows

- Start: SECURITY.md, ROADMAP.md, CONTRIBUTING.md.
- Action: read them.
- Result: SECURITY.md's scope names the Windows keyboard watcher, the Windows update chain and the clipboard, and asks for the Windows version in reports; ROADMAP.md lists Windows under Shipped; CONTRIBUTING.md says how to build and test the Windows app and that its checks run on GitHub's Windows machines.
- Checkpoint: 2
- Test: `LAUNCH-06: Security policy, roadmap and contributing cover Windows`

### LAUNCH-07: The first Windows version is public after approval

- Start: a test version James approved at Ready to ship.
- Action: run Promote and approve it.
- Result: release `windows-v0.1.0` exists with signed installers, `stable.json` points at it, and a PC on no channel can install it from the live page.
- Checkpoint: 3
- Test: `LAUNCH-07: The first Windows version is public after approval`

### LAUNCH-08: The Windows link follows each approved version

- Start: after LAUNCH-07.
- Action: promote a later version (a scratch run).
- Result: `windows/download.html` forwards to the new installer within 10 minutes of the promote finishing, with no hand edit.
- Checkpoint: 3
- Test: `LAUNCH-08: The Windows link follows each approved version`

### LAUNCH-09: The Mac download still gets the Mac app

- Start: after LAUNCH-07.
- Action: click Download for macOS on the live page and open the README's Mac link.
- Result: both reach the Mac release with its DMG; `releases/latest` is still the Mac's.
- Checkpoint: 3
- Test: `LAUNCH-09: The Mac download still gets the Mac app`

### A11Y-03: The changed page passes the accessibility floor

- Start: the changed page, desktop and phone.
- Action: run the axe scan and the contrast check; use it by keyboard.
- Result: no violations; the new text on magenta keeps AA contrast; both download buttons can be reached and used with the keyboard.
- Checkpoint: 1
- Test: `A11Y-03: The changed page passes the accessibility floor`
