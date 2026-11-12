# What working means: Windows groundwork

Plan revision: draft 1 · Approved: not yet

One section per promised outcome. The ID never changes once James has seen it; retire an ID rather than reusing it. The ID's prefix is its area, which CI uses to pick the checks a change affects. Expected behaviour only: results live under `checkpoints/`, never here.

---

### WINBASE-01: The Windows test build starts on an Intel/AMD PC

- Start: GitHub's `windows-latest` runner, the test build from this commit, no loqui installed before.
- Action: install the test build for the current user, then start loqui.
- Result: within 2 seconds the loqui microphone icon is in the notification area; its menu shows "loqui is running", "About loqui" and "Quit loqui"; About shows the version. A screenshot of the open menu and the About window is attached to the run.
- Checkpoint: 1
- Test: `WINBASE-01: The Windows test build starts on an Intel/AMD PC`

### WINBASE-02: The Windows test build starts on an Arm PC

- Start: GitHub's `windows-11-arm` runner, the Arm test build from this commit.
- Action: the same as WINBASE-01.
- Result: the same as WINBASE-01, with its own screenshot attached.
- Checkpoint: 1
- Test: `WINBASE-02: The Windows test build starts on an Arm PC`

### WINBASE-03: Quit leaves nothing running

- Start: loqui running from WINBASE-01.
- Action: choose Quit loqui.
- Result: the icon disappears and no loqui process (or web view process it started) is left running after 3 seconds.
- Checkpoint: 1
- Test: `WINBASE-03: Quit leaves nothing running`

### CLEAN-01: The cleanup rules are written down as shared examples

- Start: `shared/cleanup-cases.json` on this branch.
- Action: count the examples per rule.
- Result: at least 60 examples, at least 3 for each rule: filler removal, spelling dictionary (longest phrase wins, whole words only, any case), spoken formatting on and off, spacing and punctuation tidy, a lone "i" becoming "I", sentence healing (including the comma before which, whose and whom), timed healing for and, but and so (short gap heals, long gap doesn't, no gap measured doesn't), and capitals. Includes accented words and apostrophes.
- Checkpoint: 2
- Test: `CLEAN-01: The cleanup rules are written down as shared examples`

### CLEAN-02: The Mac app passes every shared example

- Start: the macOS check run.
- Action: `swift test`.
- Result: every example in `shared/cleanup-cases.json` passes, each listed by its id.
- Checkpoint: 2
- Test: `CLEAN-02: The Mac app passes every shared example`

### CLEAN-03: The Windows app passes every shared example

- Start: both Windows check runs.
- Action: the core tests.
- Result: every example passes on both, each listed by its id; the count matches CLEAN-02's.
- Checkpoint: 2
- Test: `CLEAN-03: The Windows app passes every shared example`

### CLEAN-04: A rule that drifts on one side fails its check

- Start: a scratch commit that changes one expected output in the shared file.
- Action: run the Mac and Windows checks.
- Result: both fail on that example's id. (Proved once, linked from the pull request; the scratch commit is not merged.)
- Checkpoint: 2
- Test: `CLEAN-04: A rule that drifts on one side fails its check`

### CLEAN-05: A Mac settings file loads unchanged on Windows

- Start: three files: a full `cleanup.json` written by the Mac app with four dictionary terms, an old one with only `dictionary` and `removeFillers`, and one with a typo that isn't valid JSON.
- Action: the Windows core loads each.
- Result: the full file loads every value; the old file keeps its terms and fills the rest with defaults; the broken file is left byte-for-byte untouched and defaults are used for that read.
- Checkpoint: 2
- Test: `CLEAN-05: A Mac settings file loads unchanged on Windows`

### PLACE-01: Where Loqui runs is recorded

- Start: this branch and the platform repo.
- Action: read `PROJECT.md` and `PLACEMENT.md`.
- Result: PROJECT.md is filled in (what it is, public, stack with the Windows choice and its reason, where it runs, staging and production, how to go back, commands). PLACEMENT.md lists Loqui under personal sites and apps as running on users' own computers, shipped from GitHub, and no longer under "New, not placed yet".
- Checkpoint: 3
- Test: `PLACE-01: Where Loqui runs is recorded`

### LOOK-01: The Windows look is one tokens file that meets contrast

- Start: `windows/design/tokens.json`.
- Action: run the playbook's token contrast check.
- Result: light and dark colours, type sizes, spacing and corners match the approved look sheet, and every text-and-background pair passes WCAG AA.
- Checkpoint: 3
- Test: `LOOK-01: The Windows look is one tokens file that meets contrast`
