# What to try: Loqui for Windows

One list for the one try. Each part adds its own section; Part E makes it one list. The pictures come from GitHub's Windows computers, taken by the Windows check with no person involved. The items marked "a teammate" are for someone on their own Windows 11 PC.

A teammate installs loqui from the test versions page once the plan is merged into staging: https://github.com/jameslaws/loqui/releases?q=windows-v&expanded=true. Open the newest "loqui for Windows … (test version)" and download `loqui-setup-…-x64.exe` (most PCs) or `loqui-setup-…-arm64.exe` (Arm laptops). Windows shows "Windows protected your PC" because loqui isn't signed by Microsoft yet: click "More info", then "Run anyway". No administrator is needed. Then turn on Settings, "Get test versions", to get every later test version by itself.

## Part A: dictation

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
A teammate: install the test build, open Notepad, tap Ctrl+Shift+Space, say a few sentences with an "um" in them, and tap it again. Then hold Ctrl+Shift+Space while talking and let go.
Where: a Windows 11 PC, with the test build from the latest Windows check
See: the bubble with its waveform while you talk, then your words in Notepad, cleaned up, with the "um" gone. Holding and letting go does the same.
Checks: DICT-01, DICT-02, DICT-05, PERF-01

## What to do
A teammate: turn off "Let desktop apps access your microphone" (Windows Settings, Privacy & security, Microphone) and tap the shortcut. Turn it back on and try again.
Where: the Windows PC with the test build
See: the bubble says what to do; after switching it back on, the next dictation works without restarting loqui.
Checks: MIC-01

## What to do
A teammate: start Notepad as administrator (right-click it, "Run as administrator") and dictate into it.
Where: the Windows PC with the test build
See: nothing is typed, the bubble says "This window won't accept typing from loqui. Your text is on the clipboard: press Ctrl+V.", and Ctrl+V pastes it.
Checks: PASTE-02

## Part B: settings, history and welcome

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
Where: the Windows PC with the test build
See: the welcome window opens by itself; the Microphone row loses its tick, then ticks itself again within 2 seconds, and Finish appears. After Finish it doesn't open again on its own; "Welcome and setup" in the tray menu brings it back.
Checks: WELC-01, WELC-02

## What to do
A teammate: in Settings, change the shortcut to Ctrl+Alt+D and dictate with it; on Dictionary, add "loki" as "Loqui" and say "I use loki every day"; in Dictation history, search, copy one and delete one; open Recent from the tray menu, click one and paste it; set Keep history to Off and dictate once; then restart Windows.
Where: the Windows PC with the test build
See: the new shortcut works at once and the old one types normally; "Loqui" spelled right; the history does what it says; Recent's item pastes in full; nothing new in history while it's Off; and loqui by the clock after signing in.
Checks: SET-01, SET-02, SET-03, SET-04, SET-05, DICTN-01, HIST-01, HIST-02, HIST-03, RECENT-01

## Part D: installer, updates and test channel

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
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Awindows-version
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
Where: https://github.com/jameslaws/loqui/actions/workflows/windows-drill.yml
See: every job green except the separate signing proof, which stops before publishing because no signing account is connected (as it should); the PC's connections all went to GitHub, only while checking or downloading; GitHub's "latest release" is still the Mac's.
Checks: SIGN-02, CHAN-03, CHAN-04, CHAN-05, PRIV-03
