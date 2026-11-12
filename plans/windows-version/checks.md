# What working means: Loqui for Windows

Plan revision: draft 1, rewritten as one plan on November 12, 2026 · Approved: yes (the Windows plan, draft 1)

One section per promised outcome. The ID never changes once James has seen it; retire an ID rather than reusing it. The ID's prefix is its area, which CI uses to pick the checks a change affects. Expected behaviour only: results live under `checkpoints/`, never here.

Every check from the old step plans 2 to 6, with the same IDs, grouped by the part that turns it green. "Checkpoint" is the numbered item in the plan's one try. Groundwork's checks (WINBASE-01 to 03, CLEAN-01 to 05, PLACE-01, LOOK-01) are in `plans/windows-groundwork/checks.md` on staging and keep passing. The old overview's WIN-01 to WIN-06 are retired: they only summed up the steps.

---

## Part A: dictation

### DICT-01: Tap to start, tap to stop, text lands at the cursor

- Start: loqui running with default settings, Notepad focused and empty.
- Action: tap Ctrl+Shift+Space, play the spoken sentence, wait 0.5 s, tap Ctrl+Shift+Space.
- Result: within 1.5 s of the second tap Notepad holds exactly "Please send the report to Sarah before Friday, and copy the whole team." A screenshot is attached.
- Checkpoint: 1, 3
- Test: `DICT-01: Tap to start, tap to stop, text lands at the cursor`

### DICT-02: Hold to talk, let go to paste

- Start: as DICT-01.
- Action: hold Ctrl+Shift+Space, play the spoken sentence, release.
- Result: the same text lands within 1.5 s of release; a short tap after it starts a new dictation (the gesture didn't stick).
- Checkpoint: 1, 3
- Test: `DICT-02: Hold to talk, let go to paste`

### DICT-03: The shortcut never reaches the app, other keys do

- Start: as DICT-01.
- Action: tap Ctrl+Shift+Space twice with no speech; then press Ctrl+Space, Ctrl+Alt+Shift+Space and type "abc".
- Result: Notepad holds only what the other keys produce ("abc"), never a space from the shortcut; holding the shortcut for 2 s adds no repeated characters.
- Checkpoint: 1
- Test: `DICT-03: The shortcut never reaches the app, other keys do`

### DICT-04: A 60-second dictation keeps its last words

- Start: as DICT-01.
- Action: tap, play a 60-second paragraph, tap.
- Result: Notepad holds the whole paragraph, including its final sentence, within 1.5 s of the second tap. The paragraph's text is compared word for word (punctuation aside).
- Checkpoint: 1
- Test: `DICT-04: A 60-second dictation keeps its last words`

### DICT-05: Cleanup and the dictionary apply

- Start: `cleanup.json` with the dictionary entry "loki" → "Loqui" and fillers on.
- Action: dictate "I use loki every day."
- Result: Notepad holds "I use Loqui every day." The cleanup audit log holds the raw and cleaned lines; the voice key log holds only the word count.
- Checkpoint: 1, 3
- Test: `DICT-05: Cleanup and the dictionary apply`

### DICT-06: Two minutes of silence stops it

- Start: as DICT-01.
- Action: tap the shortcut and play nothing.
- Result: after 120 s (±10 s) the bubble goes away, the tray icon returns to normal, nothing is pasted, and the log says it stopped after silence.
- Checkpoint: 1
- Test: `DICT-06: Two minutes of silence stops it`

### DICT-07: The Arm version turns speech into the same text

- Start: GitHub's `windows-11-arm` runner, the Arm test build with the test-only file audio source.
- Action: dictate the spoken sentence from a file through the normal path, paste into Notepad.
- Result: Notepad holds the same text as DICT-01.
- Checkpoint: 1
- Test: `DICT-07: The Arm version turns speech into the same text`

### MIC-01: Windows blocking the microphone gets a plain message

- Start: Windows' "Let desktop apps access your microphone" switched off.
- Action: tap the shortcut.
- Result: the bubble shows "Windows is blocking the microphone. Turn on "Let desktop apps access your microphone" in Settings, then try again." for about 2 s; nothing is pasted; loqui keeps running. After switching it on, the next tap works without restarting loqui.
- Checkpoint: 3
- Test: `MIC-01: Windows blocking the microphone gets a plain message`

### MIC-02: No microphone gets a plain message

- Start: no capture device (the virtual cable removed).
- Action: tap the shortcut.
- Result: the bubble shows "loqui can't find a microphone." and loqui keeps running.
- Checkpoint: 1
- Test: `MIC-02: No microphone gets a plain message`

### PASTE-01: The text stays on the clipboard, out of Windows' history and sync

- Start: after DICT-01.
- Action: read the clipboard's formats.
- Result: the clipboard holds the dictated text, plus `CanIncludeInClipboardHistory` and `CanUploadToCloudClipboard` both set to 0.
- Checkpoint: 1
- Test: `PASTE-01: The text stays on the clipboard, out of Windows' history and sync`

### PASTE-02: A window that refuses pasting gets the Ctrl+V message

- Start: Notepad started "as administrator", loqui running normally.
- Action: dictate into it.
- Result: nothing is typed; the bubble says "This window won't accept typing from loqui. Your text is on the clipboard: press Ctrl+V."; pressing Ctrl+V pastes it.
- Checkpoint: 3
- Test: `PASTE-02: A window that refuses pasting gets the Ctrl+V message`
- James judges: tried by hand by a Windows teammate on their own PC (the CI runner runs everything as administrator).

### HUD-01: The bubble never takes the cursor

- Start: as DICT-01.
- Action: during a dictation, check the foreground window every 100 ms.
- Result: Notepad stays the foreground window throughout; the bubble is visible at the bottom centre of the screen while listening, shows a spinner while finishing, and "PASTED" for about 1 s.
- Checkpoint: 1, 3
- Test: `HUD-01: The bubble never takes the cursor`

### HUD-02: The tray icon shows recording

- Start: as DICT-01.
- Action: start a dictation, take a screenshot of the notification area, stop.
- Result: the icon is magenta and pulsing while recording, and back to the plain microphone after.
- Checkpoint: 1, 3
- Test: `HUD-02: The tray icon shows recording`

### PRIV-01: loqui opens no network connection

- Start: the whole automatic run from DICT-01 to DICT-06.
- Action: list every TCP connection owned by loqui and its web view processes, every 250 ms.
- Result: none goes to an address outside the machine. The list is attached to the run.
- Checkpoint: 1
- Test: `PRIV-01: loqui opens no network connection`

### PRIV-02: Typed keys never reach any loqui file

- Start: loqui running, Notepad focused.
- Action: type a 200-character sentence with a unique word in it, then dictate once.
- Result: the unique word appears in no file under loqui's data, log or install folders.
- Checkpoint: 1
- Test: `PRIV-02: Typed keys never reach any loqui file`

### REC-01: History and stats records match the Mac's format

- Start: after DICT-01 and DICT-04.
- Action: read `history.jsonl` and `dictation-log.jsonl` under `%LOCALAPPDATA%\Loqui`.
- Result: two history lines with an ISO time and the cleaned text; two stats lines with time, word count and seconds and no text. The Mac's decoders (groundwork's tests) read both files. With retention set to off (-1), no history line is written.
- Checkpoint: 1
- Test: `REC-01: History and stats records match the Mac's format`

### PERF-01: Ready soon after start, and memory is recorded

- Start: loqui just started on the CI runner.
- Action: tap the shortcut 1 s after start and dictate the spoken sentence; record loqui's memory while idle and while dictating.
- Result: the text still lands (it waits for the model to finish loading); the pull request states the memory figures.
- Checkpoint: 1, 2
- Test: `PERF-01: Ready soon after start, and memory is recorded`
- James judges: whether it feels quick, from his Windows teammates' use.

## Part B: settings, history and welcome

### WELC-01: The welcome window opens on first start and ticks itself off

- Start: a fresh install (no `settings.json`), Windows' desktop microphone switch off.
- Action: start loqui; then turn the switch on in Windows Settings without touching loqui.
- Result: the welcome window opens by itself. The Microphone row shows "Open microphone settings", which opens Windows' microphone page. Within 2 s of turning the switch on, the row shows a tick, and the footer's Finish button becomes available.
- Checkpoint: 2
- Test: `WELC-01: The welcome window opens on first start and ticks itself off`

### WELC-02: Finish closes welcome for good, and it can be reopened

- Start: WELC-01 with the microphone allowed.
- Action: click Finish, restart loqui, then choose Welcome and setup from the tray menu.
- Result: the welcome window doesn't open on the restart; the menu item opens it again with every row ticked.
- Checkpoint: 2
- Test: `WELC-02: Finish closes welcome for good, and it can be reopened`

### SET-01: Change the shortcut by pressing it

- Start: Settings, General.
- Action: click Change, press Shift+A; then press Ctrl+Alt+D; close Settings and dictate with Ctrl+Alt+D; then press Ctrl+Shift+Space.
- Result: Shift+A is refused with "Use Ctrl or Alt with a key, or a function key."; Ctrl+Alt+D is shown as key caps and works at once; the old shortcut no longer starts a dictation and reaches the app instead. A bare F8 is also accepted. While recording a shortcut, pressing the current one doesn't start a dictation.
- Checkpoint: 4
- Test: `SET-01: Change the shortcut by pressing it`

### SET-02: Filler words can be added and removed

- Start: Settings, General, fillers on with the default list.
- Action: add "like"; run cleanup on the recognised text "I like, um, the plan"; remove "like"; run it again; turn the switch off and run it a third time.
- Result: "I the plan", then "I like, the plan", then "I like, um, the plan", the same as the Mac gives for the same input (the shared examples hold all three).
- Checkpoint: 4
- Test: `SET-02: Filler words can be added and removed`

### SET-03: How long history is kept

- Start: history with entries 1, 10 and 40 days old.
- Action: pick 30 days; then 7 days; then Off and dictate once; then Forever.
- Result: 30 days removes the 40-day entry at once; 7 days removes the 10-day one; Off saves nothing new; Forever keeps everything from then on. The same happens on the next start.
- Checkpoint: 4
- Test: `SET-03: How long history is kept`

### SET-04: Clear history asks first

- Start: history with six entries.
- Action: click Clear history, then Cancel; click it again, then Clear.
- Result: Cancel changes nothing; Clear empties the history window, Recent and `history.jsonl`. Stats records are untouched.
- Checkpoint: 4
- Test: `SET-04: Clear history asks first`

### SET-05: Start loqui when you sign in

- Start: a fresh install.
- Action: finish welcome with the switch on; sign out and in. Then turn it off in Settings and sign out and in.
- Result: with it on, loqui is by the clock after signing in and the Run entry exists; with it off, the entry is gone and loqui doesn't start.
- Checkpoint: 4
- Test: `SET-05: Start loqui when you sign in`

### DICTN-01: The dictionary can be searched and edited

- Start: Settings, Dictionary with the four sample terms.
- Action: search "forms"; clear it; Add term "grayson" → "Greyson"; edit "sarah k" to "Sara K"; delete "loki"; dictate "grayson called".
- Result: search shows only "ninja forms"; the dictation gives "Greyson called."; `cleanup.json` holds the new dictionary and still holds every other field it had before (sentence healing words, pause length).
- Checkpoint: 4
- Test: `DICTN-01: The dictionary can be searched and edited`

### HIST-01: History lists, searches, copies and deletes

- Start: the six sample entries.
- Action: open Dictation history; search "Friday"; click Copy on the result; delete another entry.
- Result: newest first, each with its date and time; the search shows only matching entries; the clipboard holds the copied text; the deleted entry is gone from the window, Recent and the file.
- Checkpoint: 4
- Test: `HIST-01: History lists, searches, copies and deletes`

### HIST-02: Empty history says how to start

- Start: no history.
- Action: open Dictation history.
- Result: "No dictations yet" and "Press Ctrl+Shift+Space anywhere and start talking." (with the current shortcut), no search results area.
- Checkpoint: 4
- Test: `HIST-02: Empty history says how to start`

### HIST-03: History updates while it's open

- Start: Dictation history open.
- Action: dictate a sentence.
- Result: it appears at the top within 1 s without reopening the window.
- Checkpoint: 4
- Test: `HIST-03: History updates while it's open`

### RECENT-01: Recent shows the last five and copies one

- Start: the six sample entries.
- Action: open the tray menu, then Recent; click the second item.
- Result: five items, newest first, each on one line cut at 48 characters with an ellipsis; the clipboard holds the full text of the second one. With no history, Recent shows "No dictations yet".
- Checkpoint: 4
- Test: `RECENT-01: Recent shows the last five and copies one`

### MENU-01: Every tray menu item does what it says

- Start: loqui running.
- Action: open the menu while idle and while dictating; choose each item.
- Result: the first line reads "Press Ctrl+Shift+Space to dictate" when idle and "Listening: press Ctrl+Shift+Space to stop" while dictating (with the current shortcut); history, Settings and Welcome open their windows; Quit quits. Dictation stats and Check for updates are present, and open their windows once Parts C and D are in.
- Checkpoint: 1
- Test: `MENU-01: Every tray menu item does what it says`

### A11Y-01: Every new window works by keyboard and passes the accessibility scan

- Start: welcome, Settings (both tabs) and history, light and dark.
- Action: run the axe scan; use each window with Tab, Shift+Tab, Space, Enter and Esc only.
- Result: no axe violations; every control can be reached and used; the focus outline is always visible; Esc closes the window.
- Checkpoint: 1
- Test: `A11Y-01: Every new window works by keyboard and passes the accessibility scan`

## Part C: stats

### STAT-01: The top of the window matches the record

- Start: the sample log, the fixed clock.
- Action: open Dictation stats from the tray menu.
- Result: the title, the all-time line (words, dictations, words each), and the Today, This week and This month cards with their "last week"/"last month" comparisons show the figures listed in the shared file.
- Checkpoint: 5
- Test: `STAT-01: The top of the window matches the record`

### STAT-02: The two charts show each day and month, with hover labels

- Start: as STAT-01.
- Action: hover, then Tab to, the bar for Oct 27 and the bar for September.
- Result: 30 daily bars and one bar per month since the first entry; each label gives the date or month and its words, matching the shared file (for example "Oct 27: 1,412 words" if that is the file's figure).
- Checkpoint: 5
- Test: `STAT-02: The two charts show each day and month, with hover labels`

### STAT-03: Patterns follow the chosen period

- Start: as STAT-01.
- Action: choose Year, Month, Week and Day in turn, step back once with the left arrow each time.
- Result: the period label spells out the period in the same wording the Mac uses for it (the shared file lists each label); the weekday chart, hour chart and eight tiles show the shared file's figures for that period; the right arrow is unavailable on the current period.
- Checkpoint: 5
- Test: `STAT-03: Patterns follow the chosen period`

### STAT-04: The calendar jumps to a shaded day

- Start: Day selected.
- Action: click the period label; go back one month; click Oct 27. Then choose Week and pick a day; choose Month and pick September; choose Year and pick 2025.
- Result: each day is shaded by its words against the busiest day ever (square-root scale), the selected day outlined; clicking Oct 27 shows that day's patterns and closes the calendar; Week picks the whole week and says so; Month shows a month grid; Year shows a list.
- Checkpoint: 5
- Test: `STAT-04: The calendar jumps to a shaded day`

### STAT-05: No dictations shows how to start

- Start: no stats record.
- Action: open Dictation stats.
- Result: "No dictations yet" with "Your words, pace and time saved show up here after your first dictation." and the current shortcut; no charts or zero tiles.
- Checkpoint: 5
- Test: `STAT-05: No dictations shows how to start`

### STAT-06: An empty period says so

- Start: the sample log.
- Action: choose Month and step to March 2026.
- Result: the tiles are replaced by "No dictations in March 2026."
- Checkpoint: 5
- Test: `STAT-06: An empty period says so`

### STAT-07: The Mac and Windows give the same figures

- Start: `shared/stats-cases.json`.
- Action: run the Mac tests and the Windows core tests.
- Result: every expected figure passes on the Mac and on both Windows runners, each listed by its id; a damaged line in the sample log is skipped by both.
- Checkpoint: 1
- Test: `STAT-07: The Mac and Windows give the same figures`

### STAT-08: The window updates while open

- Start: Dictation stats open on All time.
- Action: dictate a 12-word sentence.
- Result: Today, This week, This month and the all-time line each go up by 12 within 1 s.
- Checkpoint: 5
- Test: `STAT-08: The window updates while open`

### A11Y-02: Stats work by keyboard and pass the accessibility scan

- Start: the stats window and the open calendar, light and dark.
- Action: run the axe scan; use the period buttons, arrows, calendar and charts with the keyboard only.
- Result: no axe violations; every bar and calendar day can be reached and is read out with its date and words; Esc closes the calendar.
- Checkpoint: 1
- Test: `A11Y-02: Stats work by keyboard and pass the accessibility scan`

## Part D: installer, updates and test channel

### SIGN-01: Without Microsoft signing, every release says how to get past SmartScreen

- Start: a test version built by `windows-release.yml` with the signing switch off, as it stays for now (decision 1).
- Action: open the pre-release on GitHub; on a teammate's Windows PC, download the full installer and run it.
- Result: the release notes open with the SmartScreen steps: Windows shows "Windows protected your PC", click More info, then Run anyway; and a PC with Smart App Control turned on blocks unsigned apps. Following them installs loqui. Nothing in the installer, the app or the notes claims a publisher, and the workflow log says signing is off.
- Checkpoint: 2
- Test: `SIGN-01: Without Microsoft signing, every release says how to get past SmartScreen`

### SIGN-02: With signing switched on, an unsigned build can't be published

- Start: a scratch run with the signing switch on and no signing account connected.
- Action: run the release workflow.
- Result: it stops before creating any release or touching a feed, naming the unsigned file. (Proved once; linked from the pull request.)
- Checkpoint: 1
- Test: `SIGN-02: With signing switched on, an unsigned build can't be published`

### INST-01: It installs for the current user without an administrator

- Start: a Windows runner (and a teammate's PC) with no loqui installed, as a standard user.
- Action: run the full installer with default choices.
- Result: no administrator prompt; loqui is in Start and Installed apps; the speech model is in place; loqui starts and the welcome window opens; a dictation works.
- Checkpoint: 2
- Test: `INST-01: It installs for the current user without an administrator`

### INST-02: Uninstall asks about your data

- Start: loqui installed with history and a dictionary.
- Action: uninstall from Installed apps, once choosing Keep and once (after reinstalling) choosing Delete.
- Result: Keep removes the app and model and leaves `%LOCALAPPDATA%\Loqui` untouched; Delete removes that folder too. No loqui process, Run entry or Start entry is left either way.
- Checkpoint: 6
- Test: `INST-02: Uninstall asks about your data`

### INST-03: Installing over an older version keeps everything

- Start: version N installed with settings, dictionary, history and stats.
- Action: run version N+1's full installer.
- Result: all four are unchanged and the model isn't copied again when its version file matches.
- Checkpoint: 1
- Test: `INST-03: Installing over an older version keeps everything`

### UPD-01: A newer version installs from the prompt

- Start: test version N installed, "Get test versions" on, version N+1 on the test feed.
- Action: Check for updates; click Install and restart loqui.
- Result: the update window names both versions and shows the release notes; the download is under 30 MB; loqui restarts as N+1 with settings, dictionary, history and the model untouched.
- Checkpoint: 6
- Test: `UPD-01: A newer version installs from the prompt`

### UPD-02: An update with a bad signature is refused

- Start: a scratch feed pointing at an update installer whose updater signature doesn't match.
- Action: Check for updates and try to install.
- Result: "This update couldn't be verified, so it wasn't installed."; loqui stays on its version and keeps working.
- Checkpoint: 1
- Test: `UPD-02: An update with a bad signature is refused`

### UPD-03: Offline, the check fails quietly

- Start: networking off.
- Action: wait for the daily check; then choose Check for updates; then dictate.
- Result: nothing pops up from the daily check; the manual check says "Couldn't reach the update server. Try again later."; dictation works.
- Checkpoint: 1
- Test: `UPD-03: Offline, the check fails quietly`

### UPD-04: It checks once a day, and on demand

- Start: loqui running for 25 hours on a runner with a fake clock, feed requests counted.
- Action: none, then one Check for updates.
- Result: two automatic checks (start and 24 h later) plus one manual check.
- Checkpoint: 1
- Test: `UPD-04: It checks once a day, and on demand`

### CHAN-01: Every merge into staging becomes a test version

- Start: a merge into staging touching `windows/`, with a version higher than the last.
- Action: let `windows-release.yml` run.
- Result: within 30 minutes there is a GitHub pre-release `windows-v…-test` (not marked latest) with both installers, numbered as the app inside it is, and the test update list (the file on the fixed test-list pre-release) points at it; the release exists before the list changes. A merge whose version already exists is refused before anything is published.
- Checkpoint: 6
- Test: `CHAN-01: Every merge into staging becomes a test version`

### CHAN-02: Only PCs with test versions on get them

- Start: two PCs (runners) on version N, one with "Get test versions" on.
- Action: publish test version N+1; both check.
- Result: only the switched-on PC is offered N+1. Turning the switch off on it offers nothing until a newer stable version exists (never a downgrade).
- Checkpoint: 1
- Test: `CHAN-02: Only PCs with test versions on get them`

### CHAN-03: Promote publishes the exact files James tried

- Start: before the ship, a 0.0.x test version in the drill run on `windows-version` (the same Promote steps against a drill list, never the public one). At the ship, the 0.1.0 test version James approved.
- Action: run the Promote steps with that version (at the ship, the Lead starts them after James presses Ship in Aiva).
- Result: a `windows-v…` release whose files have the same checksums as the test version's; the list (the drill list, or `stable.json` at the ship) points at it; nothing is rebuilt. Only the repository's owner can start Promote, and only from main; anyone else's run stops before changing anything. Before the ship, no Windows release numbered 0.1.0 or above exists and the public list is untouched.
- Checkpoint: 1
- Test: `CHAN-03: Promote publishes the exact files James tried`

### CHAN-04: Roll back moves every PC to the last good version

- Start: in the drill run on `windows-version`, version B promoted after good version A, a runner PC on B reading the drill list. A, B and the rolled-back version are all 0.0.x.
- Action: run the Roll back steps naming A.
- Result: a new version numbered above B, built from A's code, is promoted (and signed, when the signing switch is on); the PC on B updates to it on its next check and behaves as A. The drill uses no number at or above 0.1.0 and never touches the public list.
- Checkpoint: 1
- Test: `CHAN-04: Roll back moves every PC to the last good version`

### CHAN-05: The Mac's download link is untouched

- Start: after CHAN-01 and CHAN-03, and again after the ship.
- Action: open `https://github.com/jameslaws/loqui/releases/latest` and the Mac appcast.
- Result: the latest release is still the Mac's, with its DMG; `docs/appcast.xml` is unchanged.
- Checkpoint: 1, 8
- Test: `CHAN-05: The Mac's download link is untouched`

### PRIV-03: The update check is the only network use

- Start: a fresh install on a runner with Part A's network watch.
- Action: install, start, finish welcome, dictate three times, check for updates, install an update.
- Result: the only outside connections are to the update list's host during update checks (`jameslaws.github.io` for the public list, `github.com` for the test list) and GitHub's release download hosts during the update download. The list is attached to the run.
- Checkpoint: 1
- Test: `PRIV-03: The update check is the only network use`

## Part E: launch

### LAUNCH-01: Windows visitors get the Windows download first

- Start: the changed page, opened in Edge on Windows 11 (Playwright with a Windows user agent, and a teammate's PC).
- Action: load the page.
- Result: the main button reads "Download for Windows" and goes to `windows/download.html`; the line under it says Windows 11 on Intel, AMD and Arm and links to the Mac download.
- Checkpoint: 7
- Test: `LAUNCH-01: Windows visitors get the Windows download first`

### LAUNCH-02: Mac visitors see today's page with Windows mentioned

- Start: the changed page in Safari on macOS.
- Action: load the page.
- Result: the main button reads "Download for macOS" and goes where it does today; a link offers the Windows download.
- Checkpoint: 7
- Test: `LAUNCH-02: Mac visitors see today's page with Windows mentioned`

### LAUNCH-03: Without scripts, both downloads show

- Start: the changed page with JavaScript off.
- Action: load the page.
- Result: both buttons are visible and work.
- Checkpoint: 7
- Test: `LAUNCH-03: Without scripts, both downloads show`

### LAUNCH-04: Phones see both, laid out cleanly

- Start: the changed page at 390 × 844.
- Action: load it on iOS Safari and Android Chrome user agents.
- Result: both buttons stacked with "loqui runs on Mac and Windows computers."; nothing overlaps or scrolls sideways.
- Checkpoint: 7
- Test: `LAUNCH-04: Phones see both, laid out cleanly`
- Phone: yes

### LAUNCH-05: The README covers Windows

- Start: README.md on the branch.
- Action: read Install, Permissions, Privacy, Security model, Uninstall, Requirements and Development.
- Result: each has its Windows part: the installer link, Windows' microphone switch, where history, stats and logs live under `%LOCALAPPDATA%\Loqui`, the keyboard watcher acting only on the shortcut, no administrator rights, not signed by Microsoft yet and how to get past SmartScreen, both update list addresses as the only network requests, uninstalling with keep or delete, Windows 11 on Intel, AMD and Arm, and building it yourself. The opening line no longer says macOS only.
- Checkpoint: 7
- Test: `LAUNCH-05: The README covers Windows`

### LAUNCH-06: Security policy, roadmap and contributing cover Windows

- Start: SECURITY.md, ROADMAP.md, CONTRIBUTING.md.
- Action: read them.
- Result: SECURITY.md's scope names the Windows keyboard watcher, the Windows update chain and the clipboard, and asks for the Windows version in reports; ROADMAP.md lists Windows under Shipped; CONTRIBUTING.md says how to build and test the Windows app and that its checks run on GitHub's Windows machines.
- Checkpoint: 7
- Test: `LAUNCH-06: Security policy, roadmap and contributing cover Windows`

### LAUNCH-07: The first Windows version is public after approval

- Start: James pressed Ship on the tested 0.1.0 test version; staging merged into main.
- Action: run Promote with that version and approve it.
- Result: release `windows-v0.1.0` exists with the tested installers (and the SmartScreen steps in its notes while signing is off), `stable.json` points at it, `windows/download.html` forwards to it, and a PC on no channel can install it from the live page.
- Checkpoint: 8
- Test: `LAUNCH-07: The first Windows version is public after approval`

### LAUNCH-08: The Windows link follows each approved version

- Start: after LAUNCH-07.
- Action: promote a later version (a scratch run).
- Result: `windows/download.html` forwards to the new installer within 10 minutes of the promote finishing, with no hand edit.
- Checkpoint: 8
- Test: `LAUNCH-08: The Windows link follows each approved version`

### LAUNCH-09: The Mac download still gets the Mac app

- Start: after LAUNCH-07.
- Action: click Download for macOS on the live page and open the README's Mac link.
- Result: both reach the Mac release with its DMG; `releases/latest` is still the Mac's.
- Checkpoint: 8
- Test: `LAUNCH-09: The Mac download still gets the Mac app`

### A11Y-03: The changed page passes the accessibility floor

- Start: the changed page, desktop and phone.
- Action: run the axe scan and the contrast check; use it by keyboard.
- Result: no violations; the new text on magenta keeps AA contrast; both download buttons can be reached and used with the keyboard.
- Checkpoint: 7
- Test: `A11Y-03: The changed page passes the accessibility floor`
