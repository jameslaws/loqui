# What working means: Signed installer, updates and a test channel for Windows

Plan revision: draft 1 · Approved: not yet

One section per promised outcome. The ID never changes once James has seen it; retire an ID rather than reusing it. The ID's prefix is its area, which CI uses to pick the checks a change affects. Expected behaviour only: results live under `checkpoints/`, never here.

---

### SIGN-01: Everything shipped is signed in James's name

- Start: a test version built by `windows-release.yml`.
- Action: verify the signatures of the full installer, the update installer, the uninstaller, loqui.exe and every DLL loqui ships.
- Result: each verifies with a trusted timestamp and the publisher "James Laws"; the file's Properties, Digital Signatures tab shows the same on the test machine.
- Checkpoint: 1, 2
- Test: `SIGN-01: Everything shipped is signed in James's name`

### SIGN-02: An unsigned build can't be published

- Start: a scratch run with signing switched off.
- Action: run the release workflow.
- Result: it stops before creating any release or touching a feed, naming the unsigned file. (Proved once; linked from the pull request.)
- Checkpoint: 2
- Test: `SIGN-02: An unsigned build can't be published`

### INST-01: It installs for the current user without an administrator

- Start: a Windows runner (and the test machine) with no loqui installed, as a standard user.
- Action: run the full installer with default choices.
- Result: no administrator prompt; loqui is in Start and Installed apps; the speech model is in place; loqui starts and the welcome window opens; a dictation works.
- Checkpoint: 2
- Test: `INST-01: It installs for the current user without an administrator`

### INST-02: Uninstall asks about your data

- Start: loqui installed with history and a dictionary.
- Action: uninstall from Installed apps, once choosing Keep and once (after reinstalling) choosing Delete.
- Result: Keep removes the app and model and leaves `%LOCALAPPDATA%\Loqui` untouched; Delete removes that folder too. No loqui process, Run entry or Start entry is left either way.
- Checkpoint: 4
- Test: `INST-02: Uninstall asks about your data`

### INST-03: Installing over an older version keeps everything

- Start: version N installed with settings, dictionary, history and stats.
- Action: run version N+1's full installer.
- Result: all four are unchanged and the model isn't copied again when its version file matches.
- Checkpoint: 2
- Test: `INST-03: Installing over an older version keeps everything`

### UPD-01: A newer version installs from the prompt

- Start: test version N installed, "Get test versions" on, version N+1 on the test feed.
- Action: Check for updates; click Install and restart loqui.
- Result: the update window names both versions and shows the release notes; the download is under 30 MB; loqui restarts as N+1 with settings, dictionary, history and the model untouched.
- Checkpoint: 3
- Test: `UPD-01: A newer version installs from the prompt`

### UPD-02: An update with a bad signature is refused

- Start: a scratch feed pointing at an update installer whose updater signature doesn't match.
- Action: Check for updates and try to install.
- Result: "This update couldn't be verified, so it wasn't installed."; loqui stays on its version and keeps working.
- Checkpoint: 3
- Test: `UPD-02: An update with a bad signature is refused`

### UPD-03: Offline, the check fails quietly

- Start: networking off.
- Action: wait for the daily check; then choose Check for updates; then dictate.
- Result: nothing pops up from the daily check; the manual check says "Couldn't reach the update server. Try again later."; dictation works.
- Checkpoint: 3
- Test: `UPD-03: Offline, the check fails quietly`

### UPD-04: It checks once a day, and on demand

- Start: loqui running for 25 hours on a runner with a fake clock, feed requests counted.
- Action: none, then one Check for updates.
- Result: two automatic checks (start and 24 h later) plus one manual check.
- Checkpoint: 3
- Test: `UPD-04: It checks once a day, and on demand`

### CHAN-01: Every merge becomes a signed test version

- Start: a merge to main touching `windows/`.
- Action: let `windows-release.yml` run.
- Result: within 30 minutes there is a GitHub pre-release `windows-v…-beta.N` (not marked latest) with both installers, and `docs/windows/beta.json` points at it; the release exists before the feed changes.
- Checkpoint: 3
- Test: `CHAN-01: Every merge becomes a signed test version`

### CHAN-02: Only PCs with test versions on get them

- Start: two PCs (runners) on version N, one with "Get test versions" on.
- Action: publish test version N+1; both check.
- Result: only the switched-on PC is offered N+1. Turning the switch off on it offers nothing until a newer stable version exists (never a downgrade).
- Checkpoint: 3
- Test: `CHAN-02: Only PCs with test versions on get them`

### CHAN-03: Promote publishes the exact files James tried

- Start: a test version approved by James at Ready to ship.
- Action: run `windows-promote.yml` with that version; James approves the environment prompt.
- Result: a `windows-v…` release whose files have the same checksums as the test version's; `stable.json` points at it; nothing is rebuilt. Without James's approval the workflow waits and changes nothing.
- Checkpoint: 4
- Test: `CHAN-03: Promote publishes the exact files James tried`

### CHAN-04: Roll back moves every PC to the last good version

- Start: stable version B published after good version A, a PC on B.
- Action: run `windows-rollback.yml` naming A.
- Result: a new version numbered above B, built from A's code, is signed and promoted; the PC on B updates to it on its next check and behaves as A.
- Checkpoint: 4
- Test: `CHAN-04: Roll back moves every PC to the last good version`

### CHAN-05: The Mac's download link is untouched

- Start: after CHAN-01 and CHAN-03.
- Action: open `https://github.com/jameslaws/loqui/releases/latest` and the Mac appcast.
- Result: the latest release is still the Mac's, with its DMG; `docs/appcast.xml` is unchanged.
- Checkpoint: 4
- Test: `CHAN-05: The Mac's download link is untouched`

### PRIV-03: The update check is the only network use

- Start: a fresh install on a runner with the network watch from step 2.
- Action: install, start, finish welcome, dictate three times, check for updates, install an update.
- Result: the only outside connections are to `jameslaws.github.io` during update checks and GitHub's release download hosts during the update download. The list is attached to the run.
- Checkpoint: 2
- Test: `PRIV-03: The update check is the only network use`
