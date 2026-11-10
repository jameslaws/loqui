---
name: core
description: Rules for every agent session in every project, learned the hard way in several of James's projects. Read at the start of every session.
metadata:
  applies_to: all
  version: "2"
---

# Core

These rules were each learned separately in two or more projects. They apply all the time, whatever the task.

## Working with James

1. Ask James only what changes the build, and only after checking the code, production and the record. Recommend an answer. Reason: he has answered most questions before.
2. A question from James is not an approval. Never change his deliberate settings because he asked "what if". "Go" in the session approves what he was shown, nothing more.
3. Never report counts, status or ids from memory. Read the live state first.
4. Never invent facts. Keep James's words verbatim. Never speak or send as James.
5. Anything James reads is plain English: no jargon, no em dashes, no "not X, it's Y", no filler. Give him web links, never Mini file paths. Use plain names for things, not metaphors.
6. Say "ready" only after it's proven on the real thing (a real build, the deployed page) by `check-changed`, the Checker's evidence or `live-check`.

## Safety

7. Never point destructive tools, tests or reseeds at live data or live sessions. `command-guard` blocks resets and destructive SQL; each project also guards database access in code; never remove or bypass a guard, hook or safety check to make an error go away.
8. Write through the owning tool or API, never straight into another system's database or files.
9. No new keys or logins. Reuse what exists. Never print or log a secret. `secret-scan` guards committed credentials.
10. An agent that reads outside content (email, web pages) gets no tools that act or send.
11. Anything that sends notifications has an age limit and a message cap.
12. Never load-test production or hammer a rate-limited service.
13. On the Mini: nothing may pop a dialog or touch iCloud. Queue heavy runs; `command-guard` blocks killing by name.
14. Files James needs go in the project, never `/tmp`.

## Git

15. Work in your own worktree and commit early. `command-guard` blocks stash, hard reset, whole-tree restores and deletion outside it. Delete by naming the files inside your own worktree or scratch folder, never with a wildcard and never right after changing folders in the same command. Reason: Claude stops those for an OK even at full access, and the session waits.
16. Read check results before committing; commit and push as separate steps. `command-guard` enforces hooks.
17. Commit locally and push once when ready. Pushes trigger builds that cost money.
18. Before you hit a usage limit, save every worktree as a work-in-progress commit.

## Lessons

19. Memory holds only facts about James and his machines. A lesson about building becomes a proposed change to the project's `PROJECT.md` or to the playbook (see the `playbook` skill). Reason: notes on one machine never reach the next project.
