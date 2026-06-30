# loqui — Brand

> A personal-line tool by James Laws. Sold off jameslaws.com. Quiet, fast,
> literary. It turns what you say into clean written words.

## Name
**loqui** — Latin *loqui*, "to speak." Pronounced *lo-KWEE*. Wordmark always
**lowercase**: `loqui`.

## The mark
A single **typographic quotation mark** ( `“` ). Rationale: it *is* the product —
capturing what was said, rendered as text. Literary (suits the Latin name),
distinctive in a category drowning in microphones and soundwaves, and type-native
(a glyph, not an illustration), which fits the editorial brand. Works tiny in the
menu bar and large as an app icon.

## Color
Primary is **James's magenta** — the through-line across this line of tools, so
they read as a family.

| Role | Value |
|---|---|
| **Magenta (primary)** | `#E91E63` · rgb(233, 30, 99) |
| Magenta deep (gradient base) | `#C2185B` |
| Off-white / cream (on magenta) | `#FBF7F2` |
| Ink (text) | `#1A1A1A` |
| Muted (secondary text) | `#6B6B6B` |
| Surface (light bg) | `#FFFFFF` / `#F7F6F4` |

Usage: magenta is the **accent and the icon ground** — not form fields, not big
flat panels of UI. Build interest from type hierarchy, not color blocking. No
green; teal only if a positive state is ever needed.

## App icon
- macOS **squircle** (Big Sur rounded-rectangle), full-bleed magenta ground.
- Subtle soft **vertical gradient** (`#E91E63` top → `#C2185B` bottom) + faint
  inner sheen. Modern depth, *not* glossy/skeuomorphic.
- A single large **opening double quotation mark** centered, in cream `#FBF7F2`,
  set in an **elegant high-contrast serif** (Didot/Bodoni feel) — thick-thin
  contrast, confident size, faint soft shadow for depth.
- Nothing else: no text, no mic, no waveform.

**Chosen + built (2026-06-29):** candidate **v2-01** (Gemini, pro image model). Master at
`design/icon/loqui-icon-1024.png` (white corners knocked out → transparent, padded to the
Apple grid). Compiled `AppIcon.icns` at the project root, wired via `CFBundleIconFile` and
copied into the bundle by `assemble-app.sh`. All raw candidates kept in `design/icon/`.

## Menu-bar glyph
**Microphone**, not the quote mark — the glyph is a *functional state indicator*, not a
shrunk logo. **Idle:** `mic` outline (monochrome template, auto-tints to the bar).
**Recording:** `mic.fill` with a slow alpha **pulse/blink** — the motion is the clear
"live" signal. Color isn't used here: the menu bar force-tints template images, so magenta
won't survive; the blink does the work. Managed via a manual `NSStatusItem` in
`LoquiApp.swift` (not SwiftUI `MenuBarExtra`, which can't animate or color the label).

## Wordmark
Keep it simple — **the icon is the logo.** The wordmark is just the name set in the
**standard Mac system font (SF Pro)**, lowercase: `loqui`. No custom logotype. Use SF Pro
Display, medium/semibold, with slight positive tracking. (System serif **New York** is an
acceptable alt if a more editorial feel is ever wanted, but SF Pro is the default.) Magenta
only as a small accent detail, never the whole word.

## Tone
Calm, literary, fast, trustworthy. Premium indie utility — the Things/Bartender
school, not a flashy AI gadget.

---

## Asset pipeline (how art becomes the app icon)
1. Generate icon candidates in Gemini from the prompt below.
2. Pick one; drop the 1024×1024 PNG into `Sources/loqui/Resources/`.
3. Claude converts it to `AppIcon.icns` (`sips` + `iconutil`), wires
   `CFBundleIconFile`/asset, and rebuilds — plus derives the monochrome menu-bar
   template from the same mark.

## Gemini image prompt (for the app icon)
> A macOS application icon, 1024×1024, in the Apple Big Sur rounded-rectangle
> (squircle) format with correct inset and corner radius. Background: a rich
> magenta (#E91E63) with a subtle soft vertical gradient — slightly brighter at
> the top, deepening toward the bottom — and a faint inner sheen. Modern, clean,
> premium; not glossy, not skeuomorphic. Centered foreground: a single large
> opening typographic double quotation mark ( “ ) in an elegant high-contrast
> serif (Didot/Bodoni style), in warm off-white (#FBF7F2), with refined
> thick-thin stroke contrast and a very faint soft drop shadow for subtle depth.
> The quotation mark is the only element — confident, generous, perfectly
> centered. Minimal, editorial, literary. No text, no microphone, no soundwave,
> no extra ornament. Crisp, high-resolution, App-Store quality.

**Variations to try:** single opening quote vs. a balanced pair; serif vs. a
clean geometric sans; flat vs. a touch more dimensional depth; cream glyph on
magenta vs. magenta glyph on cream.
