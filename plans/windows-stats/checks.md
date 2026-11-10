# What working means: Dictation stats on Windows

Plan revision: draft 1 · Approved: not yet

One section per promised outcome. The ID never changes once James has seen it; retire an ID rather than reusing it. The ID's prefix is its area, which CI uses to pick the checks a change affects. Expected behaviour only: results live under `checkpoints/`, never here.

Sample data: the dictation log in `shared/stats-cases.json`, a fixed clock of 2026-11-10 09:30 in America/New_York, weeks starting on Sunday.

---

### STAT-01: The top of the window matches the record

- Start: the sample log, the fixed clock.
- Action: open Dictation stats from the tray menu.
- Result: the title, the all-time line (words, dictations, words each), and the Today, This week and This month cards with their "last week"/"last month" comparisons show the figures listed in the shared file.
- Checkpoint: 2
- Test: `STAT-01: The top of the window matches the record`

### STAT-02: The two charts show each day and month, with hover labels

- Start: as STAT-01.
- Action: hover, then Tab to, the bar for Oct 27 and the bar for September.
- Result: 30 daily bars and one bar per month since the first entry; each label gives the date or month and its words, matching the shared file (for example "Oct 27: 1,412 words" if that is the file's figure).
- Checkpoint: 2
- Test: `STAT-02: The two charts show each day and month, with hover labels`

### STAT-03: Patterns follow the chosen period

- Start: as STAT-01.
- Action: choose Year, Month, Week and Day in turn, step back once with the left arrow each time.
- Result: the period label spells out the period in the same wording the Mac uses for it (the shared file lists each label); the weekday chart, hour chart and eight tiles show the shared file's figures for that period; the right arrow is unavailable on the current period.
- Checkpoint: 2
- Test: `STAT-03: Patterns follow the chosen period`

### STAT-04: The calendar jumps to a shaded day

- Start: Day selected.
- Action: click the period label; go back one month; click Oct 27. Then choose Week and pick a day; choose Month and pick September; choose Year and pick 2025.
- Result: each day is shaded by its words against the busiest day ever (square-root scale), the selected day outlined; clicking Oct 27 shows that day's patterns and closes the calendar; Week picks the whole week and says so; Month shows a month grid; Year shows a list.
- Checkpoint: 2
- Test: `STAT-04: The calendar jumps to a shaded day`

### STAT-05: No dictations shows how to start

- Start: no stats record.
- Action: open Dictation stats.
- Result: "No dictations yet" with "Your words, pace and time saved show up here after your first dictation." and the current shortcut; no charts or zero tiles.
- Checkpoint: 2
- Test: `STAT-05: No dictations shows how to start`

### STAT-06: An empty period says so

- Start: the sample log.
- Action: choose Month and step to March 2026.
- Result: the tiles are replaced by "No dictations in March 2026."
- Checkpoint: 2
- Test: `STAT-06: An empty period says so`

### STAT-07: The Mac and Windows give the same figures

- Start: `shared/stats-cases.json`.
- Action: run the Mac tests and the Windows core tests.
- Result: every expected figure passes on the Mac and on both Windows runners, each listed by its id; a damaged line in the sample log is skipped by both.
- Checkpoint: 1
- Test: `STAT-07: The Mac and Windows give the same figures`

### STAT-08: The window updates while open

- Start: Dictation stats open on All time.
- Action: dictate a 12-word sentence.
- Result: Today, This week, This month and the all-time line each go up by 12 within 1 s.
- Checkpoint: 2
- Test: `STAT-08: The window updates while open`

### A11Y-02: Stats work by keyboard and pass the accessibility scan

- Start: the stats window and the open calendar, light and dark.
- Action: run the axe scan; use the period buttons, arrows, calendar and charts with the keyboard only.
- Result: no axe violations; every bar and calendar day can be reached and is read out with its date and words; Esc closes the calendar.
- Checkpoint: 2
- Test: `A11Y-02: Stats work by keyboard and pass the accessibility scan`
