---
name: design-slot
description: The contract any design skill must meet to plug into the playbook, the rules every look keeps, and what a project does before a design skill exists. Use when building screens without a design skill, or when writing a design skill.
metadata:
  applies_to: apps, websites
  version: "2"
---

# The design slot

James will write his own design skill; Ninja products have the Ninja design system. The rest of the playbook relies on whichever one a project names, through this contract. `PROJECT.md` names it: `design: james-design`, `design: ninja-design-system`, or `design: proposed-in-plan`.

## Before a design skill exists

Each plan proposes its own look: 4 to 6 colours (light and dark), one or two typefaces, spacing and corner steps, shown as pictures of a mockup page drawn in that look, never as the plan's own style. James approves it with the plan. Write the tokens first, check them against the brief for generic defaults, build, then critique from screenshots. The approved tokens become the project's design file and must meet items 2, 3, 6 and 7 below. Ninja products always use the Ninja design system.

## Every look keeps these

- Build inside the product's real look: its real brand files, its live layout, or a named reference copied exactly. No new sidebars or navigation unless the plan has them.
- No generic machine-made styling: coloured stripes on card edges, default "AI" fonts, identical rounded cards everywhere, ALL-CAPS labels over every heading.
- Labels, not explainer text.
- Never below the `accessibility` floor. If a design choice would go below it, raise it with James rather than ship it.

## What a design skill provides

1. A header to the skill spec and a short plain-English summary of the look.
2. Tokens in one machine-readable file: colours (light and dark), type, spacing, corners, shadows, motion. W3C Design Tokens JSON, or YAML at the top of a `DESIGN.md`, plus how it becomes CSS variables.
3. Every allowed text and control colour pair, so contrast can be checked in both modes. A design that fails WCAG AA contrast isn't valid.
4. Shared components and when to use which: buttons, fields, dialogs, menus, lists, empty states, page header, navigation, and recipes such as a settings page or a list page. Where their code lives.
5. Layout: phone and desktop breakpoints, page widths, navigation on each.
6. Words: voice, capitalisation, how buttons and errors are phrased, banned words.
7. A gallery page in every app showing each shared component in every state, light and dark, phone and desktop. It's the only place pixel screenshots are compared, on the Mini.
8. What agents do when the design doesn't cover something: use the nearest existing pattern. A new token or component is a visible change, so it goes to James through the Lead.
9. The looks and habits to avoid, so agents don't fall back on defaults.

## Order of authority

James's approved plan and wireframes, then the project's design skill, then general guidance.

## Checked by scripts

- Colours, sizes, corners or shadows outside the tokens (escape with `design-ok: <reason>`): `scripts/no-raw-values.mjs`.
- Contrast of every allowed pair: `scripts/token-contrast.mjs`.
- Gallery screenshots against stored images: the project's acceptance checks, on the Mini only.
- A design package that changes without a deliberate upgrade: the pinned lockfile.
