---
name: crew
description: How a feature gets built (the lean way): who does what, how few messages, when to stop, and night shift rules. Use when starting, splitting, handing off or escalating work, and before a night shift.
metadata:
  applies_to: all
  version: "9"
---

# Crew

Build like one good engineer: each feature in one go, one review, normal tests, one try on staging. No process tooling is added while features wait.

## Jobs
- **Planner:** talks the idea through with James and writes the plan (`planning`). James approves it with Start building.
- **Lead**, one per project: starts the builders, merges, brings James Ready to ship. Settles small internal choices and logs them in `changes.md`. Never changes what James approved without asking him first.
- **Lead answering a waiting session:** a track session's OK or question comes to the Lead first. Answer with Aiva's command: `answer <board name> allow|deny|pass --wait <code> [--note "…"]`, or `--answer "…"` for a question. Allow only what stays in that session's own or scratch folder. Pass everything else to James: live data, other sessions, pushes, deploys, sending, keys.
- **Lead, James's words in chat:** a change to a plan: `board note` first (not questions; unsure? "Change the plan, or just asking?"), then reply "I've put that on <plan>, draft N, as a note. Not that one? Tap 'Not a change' on it." His go: `board approve <plan> --draft N "his whole message"`, then tell him.
- **Builder:** one per part the plan names, on the feature's one branch: tests and code together, in its own worktree.
- **Reviewer:** one fresh session from the other company's AI, reviews the whole finished change once (`code-standards`).
- **Shipper:** promotes the approved version and proves it's live (`shipping`).

## Skills for each job
- **Every job:** core, crew
- **Planner:** planning, stack-guide, design-slot
- **Builder:** code-standards, testing; with screens, also design-slot, accessibility
- **Reviewer:** code-standards
- **Shipper:** shipping

## The work
1. A feature is built in one go, however big: a builder per part on one feature branch, the same night, side by side unless files clash.
2. Each builder pushes once its part works. CI runs the normal suite.
3. When the whole feature is green, ask the Reviewer once. Fix real findings and push once. A plan marked risky also gets one Codex review before staging (`safety review <project> <feature>`), for real damage only; it ships once that review finds nothing to fix.
4. Once on staging: one short "what to try" list for the whole feature, with a few screenshots (`checkpoint`), and one Ship it.

## The board
5. Post only three things: "started", "stuck" (with the exact error and what you tried), and "done" (PR, what works, what to try). No progress chatter, no approvals for test changes.
6. Anything the Lead must act on goes `--kind request --to Lead`.

## When to stop
7. The same failure twice with no new evidence: stop, post "stuck" with the logs. Don't retry to green.
8. A decision only James can make (scope, a key, money): stop and ask through the Lead.

## Night shift
9. Works only from an approved queue: order, end time, accounts, how many sessions, what it must not do. It builds each feature or series whole, unless James picked step by step or it began so.
10. Never pays for extra usage, never ships to production, sends nothing to people, buys nothing, no retrying until green.
11. Interrupted? Leave a work-in-progress commit and a note of the next step. In the morning, one summary per project with links.
