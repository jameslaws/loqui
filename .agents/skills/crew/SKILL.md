---
name: crew
description: How a feature gets built (the lean way): who does what, how few messages, when to stop, and night shift rules. Use when starting, splitting, handing off or escalating work, and before a night shift.
metadata:
  applies_to: all
  version: "7"
---

# Crew

Build like one good engineer: one builder per feature, one review, normal tests, and James tries it on staging. No process tooling is added while features are waiting (James, 2026-10-24).

## Jobs
- **Planner:** talks the idea through with James and writes the plan (`planning`). James approves it with Start building.
- **Lead**, one per project: starts the builder(s), merges, brings James Ready to ship. Settles small internal choices and logs them in `changes.md`. Never changes what James approved; anything that would goes to James first.
- **Lead answering a waiting session:** a track session waiting for an OK or with a question comes to the Lead first. Answer with the command in Aiva's post: `answer <board name> allow|deny|pass --wait <code> [--note "…"]`, or `--answer "…"` for a question. Allow only what stays inside that session's own folder or scratch folder. Pass everything else to James: live data, other sessions, pushes, deploys, sending, keys.
- **Lead, James's chat change to a plan:** `board note` first (not questions; unsure? "Change the plan, or just asking?"), then reply "I've put that on <plan>, draft N, as a note. Not that one? Tap 'Not a change' on it."
- **Builder:** one per feature, or two when the plan names two parts that touch different files. Takes the plan to working on staging: tests and code together, in its own worktree.
- **Reviewer:** one fresh session from the other company's AI than the builder, reviews the finished change once (`code-standards`).
- **Shipper:** promotes the approved version and proves it's live (`shipping`).

## Skills for each job
- **Every job:** core, crew
- **Planner:** planning, stack-guide, design-slot
- **Builder:** code-standards, testing; with screens, also design-slot, accessibility
- **Reviewer:** code-standards
- **Shipper:** shipping

## The work
1. One feature at a time per project. A second builder only for a part that can't conflict.
2. The builder pushes when the feature works, not after every step. CI runs the normal suite.
3. When green, the builder asks the Reviewer once. Fix real findings, push once more. A plan marked risky also gets one Codex review before staging (`safety review <project> <feature>`), for real damage only; it ships once that review is done with nothing to fix.
4. The builder checks the feature on staging after merge and writes James's short "what to try" list with a few screenshots (`checkpoint`).

## The board
5. Post only three things: "started", "stuck" (with the exact error and what you tried), and "done" (PR, what works, what to try). No progress chatter, no approvals for test changes.
6. Anything the Lead must act on goes `--kind request --to Lead`.

## When to stop
7. The same failure twice with no new evidence: stop, post "stuck" with the logs. Don't retry to green.
8. A feature past about a day of work, or needing a decision only James can make (scope, a key, money): stop and ask through the Lead.

## Night shift
9. Works only from an approved queue: order, end time, accounts, how many sessions, what it must not do.
10. Never pays for extra usage, never ships to production, sends nothing to people, buys nothing, no retrying until green.
11. Interrupted? Leave a work-in-progress commit and a note of the next step. In the morning, one summary per project with links.
