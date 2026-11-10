# Changed from the plan: Loqui for Windows

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

Found while writing the overview (2026-11-10). The six step plans were left as they are; the Lead decides whether to correct them.

### Step 5's drill versions may use up 0.1.0 before launch

- **Kind:** Visible (waiting for James)
- **Before:** step 6 (decision 2) makes the first public Windows version 0.1.0. Step 5's checkpoint 4 promotes a version to the stable list and runs a Roll back drill, and Roll back always numbers above the bad version (CHAN-03, CHAN-04).
- **After:** not built yet. Unless step 5's drills use numbers below 0.1.0, the first version people download in step 6 will be 0.1.2 or later, and promoted Windows releases will already sit on GitHub's public releases page (unlinked) before step 6's go-public approval.
- **Why:** the two steps were planned separately. Suggested fix: step 5 numbers its drill versions 0.0.x, so 0.1.0 stays free for launch.
- **Checks affected:** CHAN-03, CHAN-04, LAUNCH-07.

### Step 5 needs step 3, not only step 2

- **Kind:** Behind it
- **Before:** step 5's `plan-needs` says 2.
- **After:** not built yet. Step 5 adds an Updates card to step 3's Settings window, wires step 3's "Check for updates" tray item, and adds `channel` to the settings file step 3 extends, so it should say 2, 3.
- **Why:** built straight after step 2, there would be no Settings window to add to. The overview builds in step order, so this only matters if steps are started out of order.
- **Checks affected:** UPD-04, CHAN-02.
