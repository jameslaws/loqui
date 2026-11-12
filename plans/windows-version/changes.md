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

Found while building Part C (2026-11-12).

### By month shows the last 12 months

- **Kind:** Behind it (the plan's own picture and the Mac already show it; the Lead confirmed it on the board, 2026-11-12)
- **Before:** STAT-02 said "one bar per month since the first entry"; the plan's stats picture and the Mac's window show the last 12 months.
- **After:** the last 12 months, this one last, as in the picture and on the Mac. Older months are still in the calendar's Month and Year views.
- **Why:** STAT-07 promises the Mac and Windows give the same figures, and the picture is what was approved.
- **Checks affected:** STAT-02 (its result now says "one bar for each of the last 12 months").

### A day is named as the Mac names it

- **Kind:** Behind it
- **Before:** the plan's calendar picture labels the chosen day "Tue, Oct 27, 2026"; STAT-03 says the label uses the Mac's wording.
- **After:** "Oct 27, 2026", "Today" or "Yesterday", the Mac's wording, as STAT-03 asks. The calendar's buttons still read out the weekday.
- **Why:** the two apps share one list of labels (shared/stats-cases.json).
- **Checks affected:** none.

### Small wording fixes the Mac doesn't have

- **Kind:** Behind it
- **Before:** the Mac says "No dictations in Yesterday.", "1 dictations" and "1,997 last week  ▼65%".
- **After:** Windows says "No dictations yesterday.", "1 dictation", and "1,997 last week · ▼ 65%" as in the plan's picture. The figures are the same; the Mac is unchanged.
- **Why:** plain English, and the picture's wording.
- **Checks affected:** none.

### Calendar shading stays readable

- **Kind:** Behind it
- **Before:** the Mac shades a day from 16% to 88% of the brand colour and turns its number white on the darkest days.
- **After:** Windows shades from 16% to 72% (the deep brand colour in light mode), on the same square-root scale against the busiest day ever, so every day's number passes the contrast check in light and dark.
- **Why:** with the Mac's range, the darkest days' numbers fail WCAG AA on Windows.
- **Checks affected:** none (STAT-04 and A11Y-02 as written).

Found while building Part D (2026-11-12).

### The update check also lets Windows confirm GitHub's certificate

- **Kind:** Behind it (the Lead settled it on the board, 2026-11-12, and is telling James)
- **Before:** PRIV-03 listed only GitHub's hosts as the update check's connections.
- **After:** the drill showed one more, during the check: Windows asking the certificate authority whether GitHub's security certificate is still valid, as it does for any secure connection. It carries nothing of the person's. loqui keeps it; PRIV-03 now names it, and the README (Part E) should say it in plain words: the update check also lets Windows confirm GitHub's certificate is still valid.
- **Why:** turning it off would mean loqui carrying its own certificate list and skipping the revocation check.
- **Checks affected:** PRIV-03 (reworded); LAUNCH-05's README wording.

### Promote has no GitHub approval step

- **Kind:** Behind it (the Lead settled it on the board, 2026-11-12: James approves in Aiva with Ship, so he has no GitHub step)
- **Before:** Promote ran behind a GitHub environment that waited for James's approval, and without it changed nothing (CHAN-03).
- **After:** James's Ship in Aiva is the approval; the Lead then starts Promote. Only the repository's owner can start it, and only from main; anyone else's run stops before changing anything. CHAN-03's action and result say so.
- **Why:** one approval, in the place James already approves things.
- **Checks affected:** CHAN-03 (reworded).

### loqui installs to AppData\Local\Programs\loqui

- **Kind:** Behind it
- **Before:** the plan's installer picture says "Installs to C:\Users\you\AppData\Local\Programs\loqui"; Tauri's installer would have put it in AppData\Local\loqui.
- **After:** as the picture says. Windows doesn't tell AppData\Local\loqui and AppData\Local\Loqui (loqui's data) apart, so the default would have put the app inside your data. A copy from an early test build is moved out of the data folder when the new installer runs, and your data stays.
- **Why:** "Keep" on uninstall must leave the data folder untouched, which it can't if the app lives in it.
- **Checks affected:** none (INST-01 and INST-02 as written).

### A newer installer installs straight over the old version

- **Kind:** Behind it
- **Before:** Tauri's installer offers "uninstall before installing" when an older loqui is there, which opens the uninstaller part way through.
- **After:** a newer full installer installs over the old version and keeps everything; an older one is refused with "A newer version of loqui is already installed, so this one wasn't." loqui uses its own copy of Tauri's installer script for this (windows/src-tauri/installer), with its changes marked.
- **Why:** INST-03, and no surprise uninstall window for teammates.
- **Checks affected:** none.

### Uninstalling asks with a tick box

- **Kind:** Behind it
- **Before:** "Uninstalling asks whether to also delete history and settings."
- **After:** the uninstaller's first page has "Also delete my dictation history, dictionary, settings and stats", unticked. Unticked keeps `%LOCALAPPDATA%\Loqui`; ticked deletes it.
- **Why:** the place Windows uninstallers ask this, and nothing is deleted unless chosen.
- **Checks affected:** none (INST-02 as written).

### Pull request test builds can't update from GitHub

- **Kind:** Behind it
- **Before:** each Windows check run attached a test build teammates could install.
- **After:** the Windows check's builds read update lists on GitHub's computer itself and are signed with a key made for the run, so the update checks run there without the real key. They still install and dictate, but never update from GitHub. Teammates install from the test channel instead (try.md), which uses the real lists and key.
- **Why:** the checks must prove updating, including a refused bad signature, without loqui's update key leaving its locked GitHub environment.
- **Checks affected:** none.

### No public list yet reads as up to date

- **Kind:** Behind it
- **Before:** the plan didn't say what a PC on the public list sees before the first public version, when that list doesn't exist.
- **After:** a missing list counts as "nothing newer", so Check for updates says "loqui is up to date" rather than "Couldn't reach the update server".
- **Why:** teammates with Get test versions off would otherwise see an error until the ship.
- **Checks affected:** none.

### Where the update checks are proved

- **Kind:** Behind it
- **Before:** UPD-04 on a runner with a fake clock; PRIV-03 over a full install and update; CHAN-04's PC behaves as A.
- **After:** UPD-04: loqui-core's schedule runs 25 hours on a fake clock (start and 24 h), and the Windows check counts the start and by-hand requests at the list. PRIV-03: proved in the drill, where loqui reads real GitHub lists; the Windows check's builds only ever reach the runner itself. CHAN-04: the drill builds A and B from the same commit, so "behaves as A" is checked as the roll back being built from A's commit, and dictating.
- **Why:** an app can't be made to live 25 real hours in a check, and only the drill uses GitHub's real hosts before the ship.
- **Checks affected:** none (wording as written).

Found while building Parts A and B (2026-11-12).

### About loqui stays in the tray menu

- **Kind:** Behind it (the Lead settled it on the board, 2026-11-12: tray apps normally have it)
- **Before:** the plan's tray menu picture has no About item.
- **After:** "About loqui" sits just above Quit, as groundwork built it.
- **Why:** groundwork's WINBASE-01 opens About from the menu and must keep passing.
- **Checks affected:** none (MENU-01 and WINBASE-01 both list it).

### loqui reads Windows' microphone switches before every dictation

- **Kind:** Behind it
- **Before:** the plan said a blocked microphone gets the message; it didn't say how loqui knows.
- **After:** loqui reads the three switches (the PC's, "Let apps access" and "Let desktop apps access") before opening the microphone, the same reading the welcome window uses, because Windows can hand a desktop app silence instead of refusing it.
- **Why:** with the switch off, GitHub's Windows computer recorded silence and no message appeared.
- **Checks affected:** none (MIC-01 as written).

### An unreadable settings file isn't saved over

- **Kind:** Behind it
- **Before:** the plan says an unreadable settings file shows "Your settings file couldn't be read, so defaults are in use" and is left alone.
- **After:** Settings shows that message, and a change made meanwhile is refused with it rather than writing over the file. The same holds for an unreadable cleanup.json.
- **Why:** saving would have replaced the very file the plan says to leave alone.
- **Checks affected:** none.

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
