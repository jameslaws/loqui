---
name: playbook
description: How the playbook itself is kept - word budgets, what a skill may hold, how lessons from projects become playbook changes, and how versions work. Use when proposing a rule, running a retro, writing or editing a skill, or upgrading a project's playbook version.
metadata:
  applies_to: all
  version: "1"
---

# Playbook

The playbook (`jameslaws/playbook`) is how James builds software. It stays small, because longer rules get followed less.

## What a skill holds

1. Only rules an agent wouldn't follow by default. Cut anything an agent already does well.
2. Anything a script can check becomes a script and leaves the skill. The skill names the script in one line.
3. A rule whose breach can't be undone is enforced in code: a hook, a limited login, a CI check. The skill names the guard.
4. The current rule only, with its reason in one line where it isn't obvious. History lives in git: no dated stories, quotes or retired systems in the text.
5. One home per rule. Other skills point to it.

## Budgets

6. Each skill, including its header, is 600 words or fewer.
7. Everything an agent loads at start is 3,000 words or fewer: the global instructions, the project's `AGENTS.md` or `CLAUDE.md`, its `PROJECT.md`, `skills/INDEX.md` and the `core` skill. Every other skill loads when its work starts.
8. Over budget means cutting, never raising the budget. `scripts/budget.mjs` fails the build when anything is over.

## Changing the playbook

9. Lessons never go in memory (`core`). A lesson learned in one project goes in that project's `PROJECT.md`, as a proposed change in a PR.
10. When a second project learns the same lesson, it becomes a playbook change proposal: a PR to `jameslaws/playbook` with the evidence in its description. The Lead merges; James sees it like any other change.
11. A retro or change that adds a rule must remove or merge one. When a check starts enforcing a rule, the rule's text is deleted.
12. Try a rule change on one real piece of work before it reaches every project. Keep a rule that changes behaviour usefully; remove one that only adds paperwork. Revisit rules when new models arrive.

## Format and versions

13. Each skill is `skills/<name>/SKILL.md`; the one exception is `skills/DESIGN-SLOT.md`. The header follows the Agent Skills spec: `name` (same as the folder) and `description` (what it does and when to load it) at the top; `applies_to` and `version` under `metadata:`.
14. `applies_to` is one or more of: `all`, `apps` (anything with screens, James's own tools included), `websites`, `on-request`.
15. A skill's `version` goes up when its rules change. The playbook is released as git tags (`v1`, `v2`). A project pins one tag in `PROJECT.md` and upgrades when James says.
16. `skills/INDEX.md` has one line per skill. Update it in the same change as the skill.
