# What working means: Loqui for Windows

Plan revision: draft 1 · Approved: not yet

One section per promised outcome. The ID never changes once James has seen it; retire an ID rather than reusing it. The ID's prefix is its area (`WIN`), which CI uses to pick the checks a change affects. Expected behaviour only: results live under `checkpoints/`, never here.

This is the series overview: one outcome per step. Each is proved by its step plan's own checks (`plans/windows-<step>/checks.md` on that step's `plan/` branch), and is green only when every one of them is.

---

### WIN-01: A Windows build starts, and both apps pass one set of cleanup rules

- Start: step 1 (groundwork) merged; its pull request's checks on GitHub.
- Action: open the checks.
- Result: both Windows checks (Intel/AMD and Arm) are green, each with a picture taken on that Windows machine of the loqui icon by the clock, its menu open and the About window. The Mac check and both Windows checks list the same cleanup examples as passed. PROJECT.md and the platform registry say where Loqui runs. Step 1's WINBASE-01 to 03, CLEAN-01 to 05, PLACE-01 and LOOK-01 all pass.
- Checkpoint: 1
- Test: `WIN-01: A Windows build starts, and both apps pass one set of cleanup rules`

### WIN-02: Speak on Windows and clean text lands at the cursor, with nothing sent anywhere

- Start: step 2 (dictation) merged; Windows 11 in Parallels on the MacBook with the test build installed; Notepad open.
- Action: tap Ctrl+Shift+Space, say a few sentences with an "um" in them, tap again. Then hold the shortcut, talk and let go. Then turn off Windows' microphone switch for desktop apps and try again.
- Result: the cleaned text lands in Notepad at the cursor with the filler gone, both ways. With the switch off, the bubble says Windows is blocking the microphone and how to turn it on. The GitHub check shows Notepad holding the spoken sentence for tap, hold and a 60-second dictation, and a line saying loqui opened no network connections. Step 2's DICT-01 to 07, MIC-01, MIC-02, PASTE-01, PASTE-02, HUD-01, HUD-02, PRIV-01, PRIV-02, REC-01 and PERF-01 all pass.
- Checkpoint: 2
- Test: `WIN-02: Speak on Windows and clean text lands at the cursor, with nothing sent anywhere`

### WIN-03: Everything set or looked back at on the Mac can be done on screen on Windows

- Start: step 3 (settings, history and welcome) merged; the Windows test machine with the new test build installed fresh.
- Action: go through the welcome window, turning the microphone switch off and on. Change the shortcut to Ctrl+Alt+D and dictate with it. Add "loki" as "Loqui" in the dictionary and say "loki". Open history, search, copy one, delete one. Open Recent and click one, then paste. Restart Windows.
- Result: the microphone row ticks itself off; the new shortcut works; "Loqui" is typed; history and Recent do what they say; after the restart loqui is by the clock. Step 3's WELC-01, WELC-02, SET-01 to 05, DICTN-01, HIST-01 to 03, RECENT-01, MENU-01 and A11Y-01 all pass.
- Checkpoint: 3
- Test: `WIN-03: Everything set or looked back at on the Mac can be done on screen on Windows`

### WIN-04: Windows shows the Mac's stats, with the same figures

- Start: step 4 (stats) merged; the Windows test machine after a few dictations.
- Action: open Dictation stats from the tray. Pick Day, click the date and choose another day from the shaded calendar; step with the arrows; pick Month and Year. Dictate once with the window open.
- Result: today's words match what was said; the calendar jumps to the chosen day; Today changes after the new dictation. On GitHub, the Mac check and both Windows checks list every shared stats figure as passed. Step 4's STAT-01 to 08 and A11Y-02 all pass.
- Checkpoint: 4
- Test: `WIN-04: Windows shows the Mac's stats, with the same figures`

### WIN-05: A signed version installs with no warnings, updates itself, and can be rolled back

- Start: step 5 (signed installer, updates and a test channel) merged; James's signing account approved by Microsoft; the Windows test machine with the old test build uninstalled.
- Action: download the newest pre-release from GitHub and install it. Turn on Get test versions. Wait for the next merged change. Approve a test version in Promote. The Lead runs a Roll back drill. Uninstall, choosing to keep history.
- Result: no administrator prompt and no "unknown publisher"; the file's properties show James Laws. The update window appears within the hour and the dictionary is still there after updating. The stable list shows the exact approved version; after Roll back the test PC returns to the previous version's behaviour. Uninstall leaves history in place. GitHub's latest release is still the Mac's. Step 5's SIGN-01, SIGN-02, INST-01 to 03, UPD-01 to 04, CHAN-01 to 05 and PRIV-03 all pass.
- Checkpoint: 5
- Test: `WIN-05: A signed version installs with no warnings, updates itself, and can be rolled back`

### WIN-06: Windows visitors get the Windows download, and the first public version is out after James approves

- Start: step 6 (launch) built; the changed download page in a private preview; a test version used daily for at least a week.
- Action: open the preview on the MacBook, the iPhone and the Windows test machine. Approve the tested version at Ready to ship. On the Windows test machine, open the live page, click Download for Windows, install and dictate. On the MacBook, click the Mac download.
- Result: Windows sees "Download for Windows" first; the Mac and the phone see today's page with Windows added. After approval, the live Windows button gets the approved version, which installs and dictates; the Mac download still gets the Mac app. Step 6's LAUNCH-01 to 09 and A11Y-03 all pass.
- Checkpoint: 6
- Test: `WIN-06: Windows visitors get the Windows download, and the first public version is out after James approves`
- Phone: yes
- James judges: whether the page and README read right for Windows.
