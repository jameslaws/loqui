---
name: checkpoint
description: How a finished feature is shown to James on staging for Ready to ship, and how his approval is recorded. Use when a feature is merged and working on staging.
metadata:
  applies_to: all
  version: "4"
---

# Ready to ship

James sees each feature once, when approving it means shipping it. No mid-build checkpoints.

1. After merge, the builder checks the feature on staging itself: the main journey on phone and desktop, using staging's data.
2. It writes James's short list in the PR and `plans/<feature>/changes.md`: what changed, three to seven things to try (where to click, what he should see), and one screenshot per item that shows something. Anything that differs from the plan is listed with why.
3. The Lead reads the list and screenshots, then brings James Ready to ship with the link.
4. James tries it on staging and presses Ship (passkey). Notes come back word for word and go to the builder; sending notes isn't approval.
5. Approval is recorded by `ship-guard` against the exact staging commit and build: one use, refused if staging moved. Never infer approval from silence or green tests.
