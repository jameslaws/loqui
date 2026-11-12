# What to try: Dictation on Windows

Step 2 of Loqui for Windows. The first five were checked on GitHub's Windows computers with no person involved, and the pictures come from them. The last three are for a Windows teammate with the test build and their own voice.

## What to do
Open the latest Windows check and look at the picture taken after a tap, a spoken sentence, and a second tap in Notepad.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Astaging
See: Notepad holding "Please send the report to Sarah before Friday, and copy the whole team." word for word, and the dark bubble at the bottom saying PASTED.
Shots: built/dict-01-listening.png, built/dict-01-pasted.png
Checks: DICT-01, DICT-02, DICT-03, HUD-01, PASTE-01

## What to do
Look at the picture after a one-minute dictation.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Astaging
See: the whole paragraph in Notepad, down to its last words "Talk soon.", and the check's line saying loqui opened no connections outside the PC.
Shots: built/dict-04-pasted.png
Checks: DICT-04, DICT-05, DICT-06, PRIV-01, PRIV-02, REC-01

## What to do
Look at the loqui icon by the clock while it listens.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Astaging
See: the microphone icon turns magenta while listening, and goes back to plain once it stops.
Shots: built/hud-02-recording.png, built/hud-02-after.png
Checks: HUD-02

## What to do
Look at the picture with Windows' microphone switch for desktop apps turned off.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Astaging
See: the bubble says "Windows is blocking the microphone. Turn on "Let desktop apps access your microphone" in Settings, then try again." Turned back on, the next dictation works.
Shots: built/mic-01-blocked.png
Checks: MIC-01, MIC-02

## What to do
Look at the same dictation on GitHub's Arm Windows computer.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Astaging
See: the same sentence, word for word, in Notepad on Windows 11 for Arm.
Shots: built/dict-07-arm-pasted.png
Checks: DICT-07

## What to do
On a Windows 11 PC: open the latest Windows check on staging, download "loqui-test-build-x64" (or "-arm64" on an Arm laptop), unzip it and run the installer. Windows will warn about an unknown publisher until step 5 signs it: choose "More info", then "Run anyway". Open Notepad, tap Ctrl+Shift+Space, say a few sentences with an "um" in them, and tap it again.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml?query=branch%3Astaging
See: the bubble with its waveform while you talk, then your words in Notepad, cleaned up, with the "um" gone. Then hold Ctrl+Shift+Space while you talk and let go: the same.
Checks: PERF-01

## What to do
Turn off "Let desktop apps access your microphone" in Windows Settings (Privacy & security, Microphone) and tap the shortcut. Turn it back on and try again.
Where: the Windows PC with the test build
See: the bubble says what to do, and after switching it back on the next dictation works without restarting loqui.
Checks: MIC-01, MIC-02

## What to do
Start Notepad as administrator (right-click it, "Run as administrator") and dictate into it.
Where: the Windows PC with the test build
See: nothing is typed, the bubble says "This window won't accept typing from loqui. Your text is on the clipboard: press Ctrl+V.", and Ctrl+V pastes it.
Checks: PASTE-02
