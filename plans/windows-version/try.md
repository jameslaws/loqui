# What to try: Loqui for Windows

One list for the one try, part by part. The pictures come from GitHub's Windows computers, taken by the checks with no person involved; the download page's pictures come from the page checks. Items marked "a teammate" are for someone on their own Windows 11 PC, with loqui installed from the teammate link: the last item says exactly how.

The teammate link: https://github.com/jameslaws/loqui/releases/tag/windows-v0.0.2-test

### Part A: dictation

## What to do
Open the latest Windows check and look at the pictures taken while dictating into Notepad and just after.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
See: the dark bubble at the bottom of the screen while it listens; then Notepad holding "Please send the report to Sarah before Friday, and copy the whole team." word for word.
Shots: built/dict-01-listening.png, built/dict-01-pasted.png
Checks: DICT-01, DICT-02, DICT-03, HUD-01, PASTE-01

## What to do
Look at the picture after a one-minute dictation.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
See: the whole paragraph in Notepad, down to its last words "Talk soon.", and the check's line saying loqui opened no connections outside the PC.
Shots: built/dict-04-pasted.png
Checks: DICT-04, DICT-05, DICT-06, PRIV-01, PRIV-02, REC-01

## What to do
Look at the loqui icon by the clock while it listens, and after.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
See: the microphone icon is magenta while listening, and plain again once it stops.
Shots: built/hud-02-recording.png, built/hud-02-after.png
Checks: HUD-02

## What to do
Look at the picture taken with Windows' microphone switch for desktop apps turned off.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
See: the bubble says "Windows is blocking the microphone. Turn on "Let desktop apps access your microphone" in Settings, then try again." With no microphone at all it says "loqui can't find a microphone."
Shots: built/mic-01-blocked.png, built/mic-02-no-microphone.png
Checks: MIC-01, MIC-02

## What to do
Look at the same dictation on GitHub's Arm Windows computer.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
See: the same sentence, word for word, in Notepad on Windows 11 for Arm.
Shots: built/dict-07-arm-pasted.png
Checks: DICT-07

## What to do
A teammate: open Notepad, tap Ctrl+Shift+Space, say a few sentences with an "um" in them, and tap it again. Then hold Ctrl+Shift+Space while talking and let go.
Where: a Windows 11 PC with loqui installed from the teammate link
See: the bubble with its waveform while you talk, then your words in Notepad, cleaned up, with the "um" gone. Holding and letting go does the same.
Checks: DICT-01, DICT-02, DICT-05, PERF-01

## What to do
A teammate: turn off "Let desktop apps access your microphone" (Windows Settings, Privacy & security, Microphone) and tap the shortcut. Turn it back on and try again.
Where: the Windows PC with loqui installed from the teammate link
See: the bubble says what to do; after switching it back on, the next dictation works without restarting loqui.
Checks: MIC-01

## What to do
A teammate: start Notepad as administrator (right-click it, "Run as administrator") and dictate into it.
Where: the Windows PC with loqui installed from the teammate link
See: nothing is typed, the bubble says "This window won't accept typing from loqui. Your text is on the clipboard: press Ctrl+V.", and Ctrl+V pastes it.
Checks: PASTE-02

### Part B: settings, history and welcome

## What to do
Look at the welcome window from loqui's first start, with Windows' microphone switch off, and again a moment after it was switched on.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
See: first, the Microphone row with "Open microphone settings" and "Finish later"; then, with nothing clicked in loqui, the row ticked and a Finish button.
Shots: built/welc-01-blocked.png, built/welc-01-ticked.png
Checks: WELC-01, WELC-02

## What to do
Look at Settings, both tabs, light and dark.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
See: General with the shortcut as key caps and Change, the filler words, how long history is kept, start at sign-in and Clear history; Dictionary with the four sample words. The shortcut picture shows Ctrl+Alt+D after it was pressed in.
Shots: built/b-settings-general-light.png, built/b-settings-general-dark.png, built/b-settings-dictionary-light.png, built/b-settings-dictionary-dark.png, built/set-01-ctrl-alt-d.png
Checks: SET-01, SET-02, SET-03, SET-04, SET-05, DICTN-01, A11Y-01

## What to do
Look at Dictation history, light and dark, after a dictation while it was open, and once cleared.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
See: newest first with date and time, Copy and delete on each; the new sentence at the top without reopening; and "No dictations yet" with the shortcut to press once cleared.
Shots: built/b-history-light.png, built/b-history-dark.png, built/hist-03-updated.png, built/hist-02-empty.png
Checks: HIST-01, HIST-02, HIST-03

## What to do
Look at the tray menu with Recent open, light and dark.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
See: "Press Ctrl+Shift+Space to dictate" at the top, every window's item, and Recent's last five dictations, each on one line.
Shots: built/b-tray-menu-light.png, built/b-tray-menu-dark.png
Checks: RECENT-01, MENU-01

## What to do
A teammate: on loqui's first start after installing, look at the welcome window. Turn "Let desktop apps access your microphone" off in Windows Settings, then on again, watching the window.
Where: the Windows PC with loqui installed from the teammate link
See: the welcome window opens by itself; the Microphone row loses its tick, then ticks itself again within 2 seconds, and Finish appears. After Finish it doesn't open again on its own; "Welcome and setup" in the tray menu brings it back.
Checks: WELC-01, WELC-02

## What to do
A teammate: in Settings, change the shortcut to Ctrl+Alt+D and dictate with it; on Dictionary, add "loki" as "Loqui" and say "I use loki every day"; in Dictation history, search, copy one and delete one; open Recent from the tray menu, click one and paste it; set Keep history to Off and dictate once; then restart Windows.
Where: the Windows PC with loqui installed from the teammate link
See: the new shortcut works at once and the old one types normally; "Loqui" spelled right; the history does what it says; Recent's item pastes in full; nothing new in history while it's Off; and loqui by the clock after signing in.
Checks: SET-01, SET-02, SET-03, SET-04, SET-05, DICTN-01, HIST-01, HIST-02, HIST-03, RECENT-01

### Part C: stats

## What to do
Look at Dictation stats on GitHub's Windows computers, light and dark, opened from the tray menu with the shared sample record moved to today.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
See: "Dictation" with 40,664 words all-time, 557 dictations and 73 words each; Today 212 and "0 yesterday"; This week and This month with last week and last month; the last 30 days and the last 12 months as bars; Patterns with its eight tiles. The damaged lines in the sample are skipped.
Shots: built/c-stats-light.png, built/c-stats-dark.png, built/c-stats-arm-light.png (on Arm)
Checks: STAT-01, STAT-02, STAT-03, A11Y-02

## What to do
Look at the calendar, light and dark, then the window after a dictation while it was open, and the window with no dictations.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
See: days shaded by their words, the busiest darkest, and "Darker days had more words"; after the 13-word sentence, Today and the all-time line up by 13 without reopening; with no record, "No dictations yet" and the shortcut to press.
Shots: built/c-stats-picker-light.png, built/c-stats-picker-dark.png, built/c-stats-updated.png, built/c-stats-empty.png
Checks: STAT-04, STAT-05, STAT-08

## What to do
Look at the Mac and Windows giving the same figures: the Windows check's core tests and the Mac's tests, each listing the shared stats figures by name.
Where: the Windows check above (step "CLEAN-03, CLEAN-05, REC-01 and STAT-07") and the Mac build on the pull request (step "CLEAN-02 and STAT-07")
See: every line of shared/stats-cases.json passing on the Mac and on both Windows computers: the top of the window, the last 30 days, the months, the calendar's busiest day and month, the damaged lines skipped, and each period from all time to a single day, including the night the clocks went back.
Checks: STAT-07

## What to do
A teammate: after a few days of dictating, open Dictation stats from the tray menu. Check Today against what you said. Choose Day, click the date, go back a month and click a dark day. Step back and forward with the arrows. Then leave the window open and dictate once.
Where: the Windows PC with loqui installed from the teammate link
See: Today matches your words; the calendar's darker days are the busy ones and a click shows that day; the right arrow stops at today; Today goes up by your words without reopening the window. A month with nothing in it says "No dictations in" that month.
Checks: STAT-01, STAT-02, STAT-03, STAT-04, STAT-05, STAT-06, STAT-08

### Part D: installer, updates and test channel

## What to do
Open the newest test version on GitHub's releases page and read the top of its notes.
Where: https://github.com/jameslaws/loqui/releases?q=windows-v&expanded=true
See: the notes open with "loqui isn't signed by Microsoft yet", then "Windows protected your PC", More info, Run anyway, and that Smart App Control blocks it; then which of the two files to download. Nothing on the page names a publisher.
Checks: SIGN-01, CHAN-01

## What to do
A teammate: download the setup file from that page and run it, choosing the defaults.
Where: a Windows 11 PC
See: "Windows protected your PC" first (More info, Run anyway), then no administrator prompt. loqui appears in Start and in Settings, Apps, Installed apps; the welcome window opens; a dictation works.
Checks: SIGN-01, INST-01

## What to do
Look at the pictures of loqui updating itself on GitHub's Windows computer.
Where: https://github.com/jameslaws/loqui/actions/runs/43342648640 (all green on Intel/AMD and Arm)
See: the update window naming both versions, the size and what's new; then the new version running, with settings, dictionary, history and the model as they were. A file signed with the wrong key is refused with "This update couldn't be verified, so it wasn't installed."; with no network, Check for updates says "Couldn't reach the update server. Try again later."
Shots: built/upd-01-prompt.png, built/upd-02-refused.png, built/upd-03-offline.png
Checks: UPD-01, UPD-02, UPD-03, UPD-04

## What to do
A teammate: in loqui's Settings, turn on "Get test versions". When the next test version is published (the builder moves the version to 0.1.0 after you install), wait for the update window, or choose Check for updates in loqui's menu by the clock, then Install and restart loqui.
Where: the Windows PC with loqui installed
See: the update window with both version numbers and what's new; loqui closes for a moment and comes back as 0.1.0; your dictionary and history are still there.
Shots: built/chan-02-switch-on.png
Checks: UPD-01, CHAN-01, CHAN-02

## What to do
A teammate: uninstall loqui from Settings, Apps, Installed apps, leaving "Also delete my dictation history, dictionary, settings and stats" unticked. Install it again from the same setup file.
Where: the Windows PC
See: the uninstaller asks about your data; after reinstalling, your history and dictionary are back as they were. Ticking the box instead removes them too.
Shots: built/inst-02-keep.png, built/inst-02-delete.png
Checks: INST-02, INST-03

## What to do
Look at the release drill: test versions A and B published, A then B promoted to the drill's own public list, and a roll back to A's code under a higher number, with a PC on GitHub's computers updating A, B, then the roll back, every connection it made listed.
Where: https://github.com/jameslaws/loqui/actions/runs/43342641690 (the drill, all green), and https://github.com/jameslaws/loqui/actions/runs/43324285409 for signing (it stops, as it should, naming the unsigned file)
See: every job green except the separate signing proof, which stops before publishing because no signing account is connected (as it should); the PC's connections all went to GitHub, plus Windows confirming GitHub's certificate, and only while checking or downloading; GitHub's "latest release" is still the Mac's.
Checks: SIGN-02, CHAN-03, CHAN-04, CHAN-05, PRIV-03

### Part E: launch

## What to do
Look at the download page as a Windows visitor sees it (Edge on Windows 11).
Where: the picture (the page goes live with the ship, because GitHub publishes it only from main)
See: "Download for Windows" as the main button, going to the Windows download page; under it "Windows 11 on Intel, AMD and Arm. Also for macOS 15 and later", the last part linking to the Mac download. Further down, "Press Ctrl+Shift+Space and talk" and the Windows stats window.
Shots: built/launch-01-windows.png
Checks: LAUNCH-01, A11Y-03

## What to do
Look at the same page as a Mac visitor, on a phone, and with scripts switched off.
Where: the pictures
See: on the Mac, today's page with "Download for macOS" going where it does today, and "Also for Windows 11" under it. On a phone, both download buttons one under the other with "loqui runs on Mac and Windows computers." and nothing sideways. With scripts off, both buttons.
Shots: built/launch-02-mac.png, built/launch-04-phone.png, built/launch-03-no-script.png
Checks: LAUNCH-02, LAUNCH-03, LAUNCH-04, A11Y-03

## What to do
Look at the Windows download page, where "Download for Windows" goes: as it is until you press Ship, and as Promote writes it for a public version.
Where: the pictures (it goes live with the ship, because GitHub publishes the page only from main)
See: until the ship, "loqui for Windows is on its way" with a link to the Mac download, so the button never leads nowhere. After a promote, "Download loqui for Windows": on a Windows PC the right installer (Intel/AMD or Arm) starts by itself; both are listed with their sizes; "Windows protected your PC", More info, Run anyway and the Smart App Control note are underneath.
Shots: built/launch-08-waiting-dark.png, built/launch-08-ready.png
Checks: LAUNCH-08, SIGN-01

## What to do
Read the Windows parts of the README, the security policy, the roadmap and the contributing notes.
Where: https://github.com/jameslaws/loqui/blob/staging/README.md, then SECURITY.md, ROADMAP.md and CONTRIBUTING.md beside it
See: the opening says Mac and Windows; Install has the Windows download link and the SmartScreen steps; Permissions names Windows' microphone switch; Privacy lists the files under %LOCALAPPDATA%\Loqui and the two update list addresses as the only network use; Security model, Uninstall, Requirements and Development each have their Windows part. SECURITY.md covers the keyboard watcher, the update chain and the clipboard; ROADMAP.md lists Windows under Shipped; CONTRIBUTING.md says how to build and test it and that its checks run on GitHub's Windows computers.
Checks: LAUNCH-05, LAUNCH-06

## What to do
Look at the test channel working end to end: one of GitHub's Windows computers, acting as a teammate's PC, installs loqui from the teammate link, dictates, turns on Get test versions, and updates itself to 0.1.0 when that test version is published.
Where: the "Windows test channel check" run linked in the pull request
See: the run green, with pictures of the switch on, the update window offering 0.1.0, loqui back as 0.1.0, and a dictation after the update.
Checks: INST-01, UPD-01, CHAN-01, CHAN-02

## What to do
You: press Ship in Aiva on 0.1.0. The Lead then runs Promote with it.
Where: https://jameslaws.github.io/loqui/ on a teammate's Windows PC and on your MacBook
See: within about 10 minutes, the Windows button starts loqui 0.1.0's installer, which installs and dictates; on your MacBook, Download for macOS still gets the Mac app, and GitHub's latest release is still the Mac's.
Checks: LAUNCH-07, LAUNCH-08, LAUNCH-09, CHAN-05

### For a teammate: install loqui for Windows

## What to do
A teammate, on their own Windows 11 PC: open the teammate link. Under "Assets", click `loqui-setup-0.0.2-x64.exe` (most PCs) or `loqui-setup-0.0.2-arm64.exe` (Arm laptops, such as a Surface Pro 11 or another Snapdragon PC) and run it. When Windows shows "Windows protected your PC", click "More info", then "Run anyway". Keep the installer's defaults. When loqui's welcome window opens, follow it; then click the loqui icon by the clock, open Settings and turn on "Get test versions".
Where: https://github.com/jameslaws/loqui/releases/tag/windows-v0.0.2-test
See: no administrator prompt; the welcome window with the Microphone row ticked, or a button to Windows' microphone settings if the switch is off; the loqui icon by the clock. In Notepad: Ctrl+Shift+Space, a sentence, Ctrl+Shift+Space again, and the words appear. Once 0.1.0 is out, "Check for updates…" in loqui's menu offers it at once (loqui also checks by itself once a day and when it starts); "Install and restart loqui" brings it back as 0.1.0 with everything kept. Then the "a teammate" items above, and tell James what needs changing.
Checks: SIGN-01, INST-01, WELC-01, UPD-01, CHAN-01, CHAN-02
