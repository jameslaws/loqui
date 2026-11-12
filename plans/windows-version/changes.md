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

Rewritten as one plan (2026-11-12).

### The Windows series became one plan, built in parts

- **Kind:** Visible (James decided: "no more features split into series of plans built over days. The Windows version should be ONE plan, built in one go: its parts listed inside the plan for builders on one feature branch, one review, one try, one ship.")
- **Before:** an overview and six step plans (plan/windows-groundwork to plan/windows-launch), each built, reviewed, tried and shipped on its own. Step 1 (groundwork) is live; step 2 (dictation) was being built.
- **After:** this plan holds all of it, still draft 1 so James's yes stands. Groundwork is done. Steps 2 to 6 are Parts A to E, built on one branch (`windows-version`), with one pull request into staging, one review, one try and one ship. Every check from steps 2 to 6 is in this folder's checks.md with the same ID; WIN-01 to WIN-06 are retired. The step plans' branches are left as written; this plan replaces steps 2 to 6.
- **Also settled by James and written in:** no Microsoft signing for now (built behind a switch that stays off; the release notes say how to get past SmartScreen; SIGN-01 and SIGN-02 reworded to match), and no Parallels (his Windows teammates install it from a link and try it). Step 5's 0.0.x drill versions are kept. The finish line is his Windows teammates installing it from a link and it updating itself. With no money left in the plan, its risk is secrets only.
- **Behind it, found while merging:** the test channel now comes from staging, because nothing reaches main before the one ship (step 5 said main). So the test update list is a file on a fixed GitHub pre-release, because GitHub Pages only serves main. Promote and Roll back are proved in a drill on the feature branch, because GitHub only starts hand-run workflows from main. The number inside the app always equals its release's number, and every merge raises it, so Promote can copy files unchanged without a PC being offered the version it has. The version moves to 0.1.0 in a one-line change after the teammates install, which is the update they see arrive.
- **Why:** James wants each feature built in one go, and the series' separate reviews, tries and ships slowed it down.
- **Checks affected:** SIGN-01, SIGN-02, CHAN-01, CHAN-03, CHAN-04, PRIV-03, LAUNCH-05, LAUNCH-07 reworded; PASTE-02, PERF-01, INST-01, LAUNCH-01 name a teammate's PC instead of the test machine; every check's checkpoint number now points at the one try; WIN-01 to WIN-06 retired.

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
