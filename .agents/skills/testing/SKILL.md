---
name: testing
description: What to test and what not to, and how tests stay reliable. Use when writing, reviewing or fixing any test, or when one fails or flickers.
metadata:
  applies_to: all
  version: "7"
---

# Testing

Tests prove the app works the way the plan says. The builder writes them with the code; the normal suite runs on every push.

## What to test
1. Every outcome in the plan's `checks.md` gets one test that would fail if the app got it wrong.
2. Where a bug does real damage (money, sign-ins, customer data, sending): test through the real database, and the sending path. Logic that's easy to get wrong (dates, rules, parsing): unit tests through public functions. Nothing else.
3. Fixing a bug: first a test that fails because of it.
4. Don't test the same thing twice, what types prove, the framework, or impossible cases. No whole-page screenshots, snapshots or coverage targets.

## Honest tests
5. Never change a test just to make it pass. If a test is wrong, say why in the commit; if the app is wrong, fix the app. The Reviewer checks every changed assertion.
6. A test that can't fail, mocks our own code, or checks how the code works instead of what a person sees is a bad test.

## Reliable tests
7. Never wait on the clock; wait for what you expect. Pin time, time zone and randomness.
8. Each test makes its own data. Fake other companies' systems at the network edge.
9. Browser tests find things by role and name.
10. A failing test is an app bug until shown otherwise. Flaky means broken: find the race, don't retry.
11. Use the project's existing test helpers. Add to them; don't build a new setup for one feature.

## Running them
12. Run the tests you touched while working; CI runs the full suite on every push. Never report "tests pass" from memory.

## Fixing failures
13. Before changing code to fix a failure, list what else uses that code (callers, screens, shared helpers) and run their checks too, not just the one that failed.
14. Fix every failure found in one round. A fix that touches app code gets the same one review a feature gets.
15. A fix to a failed full suite passes a full suite run on its own commit before it merges; the ship reuses that run. Never hand a fix back verified only by the checks that failed.

## Checked by scripts, not repeated here
- Quick checks after each step: `scripts/check-changed.mjs`.
- Focused or skipped tests left in: `scripts/no-focused-tests.mjs`.
