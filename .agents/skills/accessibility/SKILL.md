---
name: accessibility
description: The accessibility floor (WCAG 2.2 AA) for every screen and email, what the scripts already check, and the three things a person checks at checkpoints. Use when building or reviewing any page, component or email people read.
metadata:
  applies_to: apps, websites
  version: "1"
---

# Accessibility

Everything others use meets WCAG 2.2 AA. James's own tools get the scripted checks too, but not the hand-checked items. Build it right first time with real elements and the design's tokens; don't patch it afterwards.

## Building it right

1. Keyboard focus is always visible, with an outline styled to the design. Never remove it without a styled replacement, and never let a sticky header or footer hide it. Reason: keyboard users need to see where they are.
2. Use the real element (`<button>` for actions, `<a href>` for navigation, `<label>` for every field). Add ARIA only when no element does the job.
3. Anything done by dragging also works by clicking or keyboard.
4. Errors say what's wrong and how to fix it, next to the field, and focus moves to the first one. Status messages and toasts are announced (`aria-live="polite"`).
5. Respect reduced-motion settings. Nothing flashes.
6. Sign-in needs no puzzle or memory test, and password managers and pasted codes work.
7. Never ask for the same information twice in one flow.
8. Primary actions on phones are at least 44 by 44 pixels.
9. Emails carry real text, not just images, with alt text and readable contrast.

## What scripts check (don't restate, don't skip)

- The acceptance checks run an axe scan, limited to the WCAG 2.0 to 2.2 A and AA rules, at every screen state they visit (loaded, dialog open, error shown). The Checker adds the scan when writing the checks; any violation fails.
- The same checks tab through each main screen (every control reached, focus visible) and load it 320 pixels wide (no sideways scrolling).
- Contrast of every allowed colour pair, light and dark: `scripts/token-contrast.mjs`.
- The linter's accessibility rules stay on (Biome's `a11y` group or the stack's equivalent).
- Sizes agents get wrong by default (James, 2026-10-22): every text box uses 16px text or larger at phone size, or iPhone Safari zooms the page on tap. Expand and collapse arrows are at least 16px, centred in a 24px or larger tap target. Checkboxes sit centred on the first line of their label. The acceptance checks measure all three at phone size.
- A violation that truly can't be fixed goes in the project's one exceptions file with its reason and an issue link. Never switch a rule off everywhere.

## What a person checks

For anything others use, the Checker adds these three items to every checkpoint:

- "Use the new screens with only the keyboard: Tab, Enter, Esc. You can reach and use everything, and you can always see where you are."
- "Zoom the browser to 200%, and open it on your phone. Nothing is cut off or overlapping."
- "Turn on VoiceOver (Command-F5) on the main new screen. Buttons and fields are read out with sensible names."

Before the public launch of an app others depend on, the launch plan includes one full manual review against WCAG 2.2 AA.
