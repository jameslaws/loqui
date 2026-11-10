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

Found while writing the overview (2026-11-10). The Lead agreed both the same day, and step 5's plan (plan/windows-release) was corrected; the overview matches it.

### Step 5's practice versions are numbered 0.0.x

- **Kind:** Visible (waiting for James)
- **Before:** step 6 (decision 2) makes the first public Windows version 0.1.0, but step 5's checkpoint 4 promotes a version to the stable list and runs a Roll back drill, and Roll back always numbers above the bad version (CHAN-03, CHAN-04). Those drills could have used up 0.1.0, so the first version people download would have been 0.1.2 or later.
- **After:** step 5's plan now numbers every Windows version before launch, test and stable, 0.0.x, drills included. 0.1.0 stays free for step 6. The overview says so under signing and updates, decision 14, checkpoint 5 and WIN-05.
- **Why:** the two steps were planned separately and their numbering clashed.
- **Checks affected:** CHAN-03, CHAN-04 (step 5, wording of start and result), WIN-05.

### Step 5 needs step 3, not only step 2

- **Kind:** Behind it
- **Before:** step 5's `plan-needs` said 2.
- **After:** it now says 2, 3. Step 5 adds an Updates card to step 3's Settings window, wires step 3's "Check for updates" tray item, and adds `channel` to the settings file step 3 extends.
- **Why:** built straight after step 2, there would be no Settings window to add to.
- **Checks affected:** none.
