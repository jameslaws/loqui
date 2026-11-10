---
name: code-standards
description: How code is shaped and reviewed in every project. Builders and reviewers load the same rules. Use when writing, reviewing or answering a review of any code.
metadata:
  applies_to: all
  version: "3"
---

# Code standards

Builders and reviewers read the same rules, so review finds real problems instead of a predictable round of fixes. Anything a script can check is a script, not a line here.

## Scope

1. Build everything the plan asks for and nothing else: no extra options, settings, refactors or hooks for imagined needs.
2. Never remove an existing feature unless the plan says so.
3. Found a problem in or next to your change? Fix it in the same change. Otherwise add one line to an existing issue for the whole job. Never open a new card for James.

## Repetition and shape

4. Every product rule has one home: money, permissions, who sees what, dates and time zones, notification wording, status names. A second copy is a bug, even the first time.
5. Other code: two similar copies are fine; extract on the third. Code that looks alike but means different things isn't repetition.
6. When a shared helper has grown flags for each caller, put the code back into the callers and start again.
7. Prefer a few modules that hide a lot behind a small interface over many thin layers. Add an extension point only when there are two real uses.
8. Names come from the project's `GLOSSARY.md` (started with the first plan), in the product's words.
9. A failed load shows an error with a retry, never an empty screen or zeros.

## Dependencies

10. Use the language and platform first. A new package needs one line in the PR: what it does that a few lines can't, and that it's maintained.

## Review
11. One review per change, once it works, by a fresh session from the other company's AI than the builder, against the plan, `checks.md` and this skill. Give it the diff and the plan.
12. A finding names a concrete failure: these inputs or this state, this wrong result. Security, data loss, sending and permissions findings block until fixed. Taste is noted, not argued.
13. One round. The builder fixes the findings and pushes once; the reviewer checks those fixes only. Anything still disputed goes to the Lead, who decides; a confirmed security or data finding is never waved through.
14. When review catches the same kind of mistake twice, it becomes a check.

## Checked by scripts, not repeated here

- Format, lint, strict types, dead code and unused packages: the project's `check` script (Biome, `tsc`, Knip; Pint and Larastan for Laravel), run by `scripts/check-changed.mjs` and CI.
- Files over about 800 lines taking on new work: `scripts/file-size.mjs`.
