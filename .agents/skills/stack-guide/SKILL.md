---
name: stack-guide
description: The default tools for each kind of project, why they're the default, and when to choose otherwise. Use when planning a new project or feature, adding a dependency, or when a plan proposes something off the default.
metadata:
  applies_to: all
  version: "1"
---

# Stack guide

Defaults with reasons, not bans. A plan can choose otherwise by stating why. `PLACEMENT.md` decides where things run; the hosting notes here match it.

## Defaults

- **Website:** Astro, built to static files; a single page can be plain HTML and CSS. Hosted on Cloudflare Workers as static assets if that's free, otherwise Cloudflare Pages. It's free while the site is static files only, with no Worker code run on each visit (checked 2026-10-22). Existing Pages sites stay put. Why: free, push to publish, and Cloudflare now points new projects at Workers.
- **App others use:** TypeScript, React + Vite for the screens, a small Hono server on Node, Postgres with Drizzle, Tailwind with shadcn/ui unless the design skill supplies its own CSS. Better Auth only if it needs its own accounts. One container on jl-platform. Why: types catch most agent mistakes, one simple container, and none of the server-component security holes that hit self-hosted Next.js in 2025.
- **James's own tool:** the same screens, Node's built-in server or Hono run directly with Node's type stripping, SQLite. On the Mini.
- **Mac or iPhone app:** first ask whether a Home Screen web app would do. If not, Swift and SwiftUI.
- **Company product:** whatever it already uses.
- **Everywhere:** Node's current long-term support line, pnpm, Biome, Vitest in projects with screens, Node's test runner in server-only projects, Playwright for browser checks.

## Good reasons to choose otherwise

- **Laravel** when the project lives in the WordPress or Ninja Forms world, or whoever takes it over works in PHP. Agents write PHP about as well.
- **Next.js or another server-rendered framework** when public pages must rank in search and share components with the app. Then: one container, security releases applied within 48 hours, and the framework's version-matched docs in the repo.
- **Postgres for a private tool** when more than one machine writes to it.
- **SQLite for an app others use** only if it's one small container with a backup streaming off the server.
- **Plain CSS with tokens** when an approved design already defines the look in CSS. Copy it; don't translate it.
- **Swift** for menu-bar apps, widgets, share sheets, hardware, background audio or the App Store.

## Rules

1. Don't add a second tool for a job the stack already covers: a second test runner, CSS system, date library or ORM.
2. Pin exact versions and commit the lockfile. Never install a release candidate; check that `latest` is a stable release first.
3. Keep pnpm's safety settings: new releases wait a day, and package install scripts are blocked unless listed.
4. Put the framework's version-matched docs where agents read them, when it ships them.
5. One server process until the plan shows a need for more.
6. SQLite 3.51.3 or later, in WAL mode on a local disk, never in a synced folder (Syncthing, iCloud).
7. Postgres has scheduled off-server backups, and a restore is tested before going live.
8. Every repo has the same scripts: `dev`, `check` (format, lint, types, tests, build), `check:changed`, `test:acceptance`, `test:contracts`, `start`. CI, the Checker and `check-changed` call only these.

Anything off the defaults goes in the plan's Decisions (`planning`). Re-check the defaults every six months, or after a serious security release.
