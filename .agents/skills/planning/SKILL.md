---
name: planning
description: Turn a talked-through idea into a plan page with pictures of its screens and a checklist (checks.md) that James approves before anything is built. Use for a new project or a new feature of an existing one.
metadata:
  applies_to: all
  version: "6"
---

# Planning

The plan is for James to approve; its handoff section is for agents to build from. A feature of an existing project gets the same full plan, written knowing that project's screens, design and code.

## Before writing

1. Read `PROJECT.md`, the live product and the code first. Reuse existing patterns, keep James's words, never re-ask a settled question.
2. Ask one question at a time, each with a recommendation (see `core`). The Lead settles internal choices.
3. Prove an uncertain capability with a small experiment before the plan promises it, and record what it showed.

## The files

4. Start from `templates/plan/`. The feature lives in `plans/<feature>/`: `plan.html`, `checks.md`, `changes.md` and `shots/`. Keep every draft.
5. Aiva draws every plan in one look: a plan is words, James's quotes and pictures in the template's sections and order, which `scripts/plan-check.mjs` checks before you push. A section only this plan needs goes between What changes and Screens; an empty one says "None".

## What the plan holds

6. For James, in plain English: what changes and who it's for (the access level); every affected screen at phone and desktop size, with its empty, loading, error and no-permission states; risk; decisions, each with a recommendation, including anything off the stack guide's defaults; what's out of scope; checkpoints (detail in `checks.md`).
7. Screens are pictures: "before" is the real app; "after" is the real app with the change made in the page, or the product's look drawn in a separate page and photographed (`templates/plan/shoot.mjs`).
8. Every plan keeps to these: everything a feature needs can be set up and edited on screen, never hidden in seed data or code; if a machine can track it, James never types it; it works on a phone; empty sections show nothing.
9. One feature is one plan, however big; never size or split it by build time. Its parts are built in one go (`crew`); James sees it once, on staging. A series only when James asks or would ship the parts apart. Name plans it replaces in `plan-replaces`.
10. Agent handoff, one per part, small fixes included: which check IDs it must turn green and which existing tests it changes; existing code to reuse, shared interfaces and who owns each, dependencies and order, data and outside services touched, which changes can't be undone, staging and rollback notes. Settle boundaries builders could decide incompatibly; leave the rest to them.
11. Mark `plan-risk` (data, access, sends, money, secrets) or `none`. Risky: it changes data (structure, deleting, moving), who sees what, sends to people, keys and secrets, or money (spending more, payments, refunds, billing that could charge more; never a cut).

## checks.md

12. One stable ID per promised outcome (`PAUSE-01`), using the format in `templates/plan/checks.md`: start, action, visible result. Include the failure and permission cases that matter. No vague items ("works well").
13. Where an item needs taste ("40 steps still readable"), give it an objective part a script can prove and mark the rest "James judges".

## Approval

14. Before James sees it, the Lead checks: `plan-check` passes, no open product question, every shared interface has an owner, every outcome is testable.
15. James approves one specific revision of the plan and checklist. That approval is the go. Later changes are recorded in `changes.md` (see `checkpoint`).
