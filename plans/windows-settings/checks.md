# What working means: Settings, history and welcome on Windows

Plan revision: draft 1 · Approved: not yet

One section per promised outcome. The ID never changes once James has seen it; retire an ID rather than reusing it. The ID's prefix is its area, which CI uses to pick the checks a change affects. Expected behaviour only: results live under `checkpoints/`, never here.

Sample data for the automatic checks: six history entries and the four-term dictionary used in the plan's pictures.

---

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
- Checkpoint: 2
- Test: `SET-01: Change the shortcut by pressing it`

### SET-02: Filler words can be added and removed

- Start: Settings, General, fillers on with the default list.
- Action: add "like"; run cleanup on the recognised text "I like, um, the plan"; remove "like"; run it again; turn the switch off and run it a third time.
- Result: "I the plan", then "I like, the plan", then "I like, um, the plan", the same as the Mac gives for the same input (the shared examples hold all three).
- Checkpoint: 2
- Test: `SET-02: Filler words can be added and removed`

### SET-03: How long history is kept

- Start: history with entries 1, 10 and 40 days old.
- Action: pick 30 days; then 7 days; then Off and dictate once; then Forever.
- Result: 30 days removes the 40-day entry at once; 7 days removes the 10-day one; Off saves nothing new; Forever keeps everything from then on. The same happens on the next start.
- Checkpoint: 3
- Test: `SET-03: How long history is kept`

### SET-04: Clear history asks first

- Start: history with six entries.
- Action: click Clear history, then Cancel; click it again, then Clear.
- Result: Cancel changes nothing; Clear empties the history window, Recent and `history.jsonl`. Stats records are untouched.
- Checkpoint: 3
- Test: `SET-04: Clear history asks first`

### SET-05: Start loqui when you sign in

- Start: a fresh install.
- Action: finish welcome with the switch on; sign out and in. Then turn it off in Settings and sign out and in.
- Result: with it on, loqui is by the clock after signing in and the Run entry exists; with it off, the entry is gone and loqui doesn't start.
- Checkpoint: 3
- Test: `SET-05: Start loqui when you sign in`

### DICTN-01: The dictionary can be searched and edited

- Start: Settings, Dictionary with the four sample terms.
- Action: search "forms"; clear it; Add term "grayson" → "Greyson"; edit "sarah k" to "Sara K"; delete "loki"; dictate "grayson called".
- Result: search shows only "ninja forms"; the dictation gives "Greyson called."; `cleanup.json` holds the new dictionary and still holds every other field it had before (sentence healing words, pause length).
- Checkpoint: 2
- Test: `DICTN-01: The dictionary can be searched and edited`

### HIST-01: History lists, searches, copies and deletes

- Start: the six sample entries.
- Action: open Dictation history; search "Friday"; click Copy on the result; delete another entry.
- Result: newest first, each with its date and time; the search shows only matching entries; the clipboard holds the copied text; the deleted entry is gone from the window, Recent and the file.
- Checkpoint: 3
- Test: `HIST-01: History lists, searches, copies and deletes`

### HIST-02: Empty history says how to start

- Start: no history.
- Action: open Dictation history.
- Result: "No dictations yet" and "Press Ctrl+Shift+Space anywhere and start talking." (with the current shortcut), no search results area.
- Checkpoint: 3
- Test: `HIST-02: Empty history says how to start`

### HIST-03: History updates while it's open

- Start: Dictation history open.
- Action: dictate a sentence.
- Result: it appears at the top within 1 s without reopening the window.
- Checkpoint: 3
- Test: `HIST-03: History updates while it's open`

### RECENT-01: Recent shows the last five and copies one

- Start: the six sample entries.
- Action: open the tray menu, then Recent; click the second item.
- Result: five items, newest first, each on one line cut at 48 characters with an ellipsis; the clipboard holds the full text of the second one. With no history, Recent shows "No dictations yet".
- Checkpoint: 3
- Test: `RECENT-01: Recent shows the last five and copies one`

### MENU-01: Every tray menu item does what it says

- Start: loqui running.
- Action: open the menu while idle and while dictating; choose each item.
- Result: the first line reads "Press Ctrl+Shift+Space to dictate" when idle and "Listening: press Ctrl+Shift+Space to stop" while dictating (with the current shortcut); history, Settings and Welcome open their windows; Quit quits. Dictation stats and Check for updates are present and wired in steps 4 and 5.
- Checkpoint: 1
- Test: `MENU-01: Every tray menu item does what it says`

### A11Y-01: Every new window works by keyboard and passes the accessibility scan

- Start: welcome, Settings (both tabs) and history, light and dark.
- Action: run the axe scan; use each window with Tab, Shift+Tab, Space, Enter and Esc only.
- Result: no axe violations; every control can be reached and used; the focus outline is always visible; Esc closes the window.
- Checkpoint: 1
- Test: `A11Y-01: Every new window works by keyboard and passes the accessibility scan`
