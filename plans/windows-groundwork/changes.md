# Changed from the plan: Windows groundwork

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

### The About window says version 0.0.1, not 0.1.0

- **Kind:** Visible (decided in the approved series plan: "every Windows version before launch, test and stable ... is 0.0.x")
- **Before:** the About mockup shows "Version 0.1.0 (test build)".
- **After:** "Version 0.0.1 (test build)". The version lives only in windows/package.json.
- **Why:** step 6 makes 0.1.0 the first public Windows version.
- **Checks affected:** WINBASE-01, WINBASE-02 (they read the version from package.json).

### The lightest grey is for lines only, not text

- **Kind:** Visible (waiting for James)
- **Before:** the look sheet draws empty-field placeholder text in the lightest grey (faint).
- **After:** faint is allowed for lines and control outlines only. Placeholder text uses the muted grey, a little darker.
- **Why:** faint on white is 3.7 to 1, under the 4.5 to 1 that text needs; the plan promises every text pair passes. Nothing in step 1 shows a placeholder; step 3's fields are the first.
- **Checks affected:** LOOK-01.

### The contrast check runs inside the project's own tests

- **Kind:** Behind it
- **Before:** LOOK-01 runs the playbook's token contrast check.
- **After:** the playbook's check passed on the Mini against windows/design/tokens.json; CI runs the same WCAG formula as a project test, which also compares the tokens with the look sheet.
- **Why:** the playbook repo is private and Loqui's is public, so CI can't fetch the playbook and copying it in would publish it.
- **Checks affected:** LOOK-01.

### Playwright waits for the first screens

- **Kind:** Behind it
- **Before:** the stack lists Playwright.
- **After:** not installed yet. Step 1's only page is About, checked on the real Windows desktop instead.
- **Why:** no browser tests to run until step 3's screens; an unused package is dead weight.
- **Checks affected:** none.
