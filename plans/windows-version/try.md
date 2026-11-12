# What to try: Loqui for Windows

One list for the one try. Each part adds its own section; Part E makes it one list. The pictures come from GitHub's Windows computers, taken by the Windows check with no person involved. The items marked "a teammate" are for someone on their own Windows 11 PC.

Until Part D adds the installer link, a teammate gets loqui like this: open the latest Windows check on the `windows-version` branch, download "loqui-test-build-x64" (or "loqui-test-build-arm64" on an Arm laptop), unzip it and run the installer. Windows warns about an unknown publisher because loqui isn't signed by Microsoft: choose "More info", then "Run anyway". No administrator is needed.

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
