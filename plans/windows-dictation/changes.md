# Changed from the plan: Dictation on Windows

The Lead adds an entry whenever the build differs from the approved plan. Newest first. Never edit an old entry; add a new one.

Classify by what a user sees or does, not by where the code changed. **Visible** means a user would notice: a screen, a control, a wording, or how something behaves. Visible changes wait for James's decision. **Behind it** changes are listed at the next checkpoint for reading only.

Format:

### Short title

- **Kind:** Visible (waiting for James) | Visible (James decided: his words) | Behind it
- **Before:** what the plan said.
- **After:** what was built instead.
- **Why:** one line.
- **Checks affected:** IDs, or none.

---

### Three more plain messages for rare failures, and a new About line

- **Kind:** Visible (waiting for James)
- **Before:** the plan listed the bubble's messages for a blocked microphone, no microphone and a window that refuses typing. The About window said "Dictation arrives in the next step."
- **After:** three more, for failures the plan didn't cover: "loqui can't use the microphone right now. Try again in a moment." (the microphone fails to open for any other reason), "loqui couldn't reach the clipboard, so nothing was pasted. Try again." and "loqui couldn't load its speech model. Reinstall loqui to fix it." The About window now says "Press Ctrl+Shift+Space, speak, and press it again. Your words land where you're typing."
- **Why:** a failure must show a message, never nothing; the old About line stopped being true.
- **Checks affected:** none.

### Your own voice: a Windows teammate instead of Parallels

- **Kind:** Visible (James decided: "Go ahead and build it entirely until there's something for one of my, team members who use Windows can install it and test it.")
- **Before:** decision 5: Parallels on James's MacBook for checkpoint 2.
- **After:** a Windows teammate installs the test build from the Windows check on `staging` and tries checkpoint 2. Every check before that runs on GitHub's Windows computers.
- **Why:** James's call on 2026-11-12.
- **Checks affected:** MIC-01, MIC-02, PASTE-02, PERF-01 (checkpoint 2 is tried by the teammate).

### The clipboard message stays up for 3 seconds

- **Kind:** Behind it
- **Before:** bubble notices last about 2 seconds, as on the Mac.
- **After:** the microphone messages last 1.8 seconds as on the Mac; the longer "press Ctrl+V" message lasts 3 seconds so it can be read.
- **Why:** it's twice as long and tells you what to do next.
- **Checks affected:** PASTE-02.

### Windows converts the microphone's sound, not loqui

- **Kind:** Behind it
- **Before:** loqui resamples the microphone to 16 kHz mono itself.
- **After:** loqui asks Windows' audio system for 16 kHz mono and Windows converts it, at its default quality.
- **Why:** less code and better quality than a hand-written converter.
- **Checks affected:** none.

### Log times are written in UTC

- **Kind:** Behind it
- **Before:** the Mac writes its voice key and cleanup logs with local times like "Nov 12, 2026 at 2:03:22 PM".
- **After:** Windows writes `2026-11-12T19:03:22Z`. History and stats use the Mac's exact format.
- **Why:** the logs are for diagnosing, not for steps 3 and 4, and UTC needs no time zone code.
- **Checks affected:** none.

### Settings and history live beside the installed app

- **Kind:** Behind it
- **Before:** loqui keeps its files under `%LOCALAPPDATA%\Loqui`.
- **After:** unchanged, but the test installer also installs loqui to `%LOCALAPPDATA%\loqui`, which Windows treats as the same folder. Step 5's installer must keep `settings.json`, `history.jsonl`, `dictation-log.jsonl`, `cleanup.json` and `logs\` when it updates or uninstalls (unless the person chooses to delete them).
- **Why:** a note for step 5, which owns the installer.
- **Checks affected:** none.
