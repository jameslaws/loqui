# What working means: Dictation on Windows

Plan revision: draft 1 · Approved: not yet

One section per promised outcome. The ID never changes once James has seen it; retire an ID rather than reusing it. The ID's prefix is its area, which CI uses to pick the checks a change affects. Expected behaviour only: results live under `checkpoints/`, never here.

The automatic runs below happen on GitHub's `windows-latest` runner with a virtual sound cable as the microphone, Windows' desktop microphone switch on, Notepad open and focused, and speech made by Windows' own voice (System.Speech). "Spoken sentence" means: "Please send the report to Sarah before Friday, and copy the whole team."

---

### DICT-01: Tap to start, tap to stop, text lands at the cursor

- Start: loqui running with default settings, Notepad focused and empty.
- Action: tap Ctrl+Shift+Space, play the spoken sentence, wait 0.5 s, tap Ctrl+Shift+Space.
- Result: within 1.5 s of the second tap Notepad holds exactly "Please send the report to Sarah before Friday, and copy the whole team." A screenshot is attached.
- Checkpoint: 1
- Test: `DICT-01: Tap to start, tap to stop, text lands at the cursor`

### DICT-02: Hold to talk, let go to paste

- Start: as DICT-01.
- Action: hold Ctrl+Shift+Space, play the spoken sentence, release.
- Result: the same text lands within 1.5 s of release; a short tap after it starts a new dictation (the gesture didn't stick).
- Checkpoint: 1
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
- Checkpoint: 1
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
- Checkpoint: 2
- Test: `MIC-01: Windows blocking the microphone gets a plain message`

### MIC-02: No microphone gets a plain message

- Start: no capture device (the virtual cable removed).
- Action: tap the shortcut.
- Result: the bubble shows "loqui can't find a microphone." and loqui keeps running.
- Checkpoint: 2
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
- Checkpoint: 2
- Test: `PASTE-02: A window that refuses pasting gets the Ctrl+V message`
- James judges: tried by hand on the Windows test machine (the CI runner runs everything as administrator).

### HUD-01: The bubble never takes the cursor

- Start: as DICT-01.
- Action: during a dictation, check the foreground window every 100 ms.
- Result: Notepad stays the foreground window throughout; the bubble is visible at the bottom centre of the screen while listening, shows a spinner while finishing, and "PASTED" for about 1 s.
- Checkpoint: 1
- Test: `HUD-01: The bubble never takes the cursor`

### HUD-02: The tray icon shows recording

- Start: as DICT-01.
- Action: start a dictation, take a screenshot of the notification area, stop.
- Result: the icon is magenta and pulsing while recording, and back to the plain microphone after.
- Checkpoint: 1
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
- Result: two history lines with an ISO time and the cleaned text; two stats lines with time, word count and seconds and no text. The Mac's decoders (step 1's tests) read both files. With retention set to off (-1), no history line is written.
- Checkpoint: 1
- Test: `REC-01: History and stats records match the Mac's format`

### PERF-01: Ready soon after start, and memory is recorded

- Start: loqui just started on the CI runner.
- Action: tap the shortcut 1 s after start and dictate the spoken sentence; record loqui's memory while idle and while dictating.
- Result: the text still lands (it waits for the model to finish loading); the pull request states the memory figures.
- Checkpoint: 2
- Test: `PERF-01: Ready soon after start, and memory is recorded`
- James judges: whether it feels quick on the Windows test machine.
