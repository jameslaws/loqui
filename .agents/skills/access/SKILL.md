---
name: access
description: Who can use a project (just James, the public, the Saturday Drive team, or anyone who signs up) and how apps are built so moving between them is a setting, not a rebuild. Use when planning or building anything with a web address, or when who it's for changes.
metadata:
  applies_to: apps, websites
  version: "1"
---

# Access

James often decides who something is for after it's built, so changing it must be a setting. A gate in front of the app does the checking; the app asks one function "who is this?". Only open sign-up needs the app to keep its own accounts.

## The four levels

The level is `access:` in `PROJECT.md` and the app's `ACCESS` setting.

- **`private`, just James.** On the Mini: Tailscale only (`tailscale serve`), identity from the `Tailscale-User-Login` header. Elsewhere: Cloudflare Access allowing James's emails, identity from the Access token.
- **`public`.** No gate.
- **`team`, the Saturday Drive team:** anyone signed in with an @saturdaydrive.com Google account, through Cloudflare Access with Google Workspace sign-in. Use a Workspace group only when a tool needs a smaller group.
- **`signup`, anyone who signs up.** The app's own accounts: Better Auth in TypeScript, the starter kit in Laravel.

## Rules

1. Every app has one function, `currentPerson(request)`, returning `{ email, name }` or nothing. All other code asks it. Nothing else reads identity headers or cookies.
2. It trusts a source only when `ACCESS` says so:
   - `private` on the Mini: the Tailscale header, and the server listens only on `127.0.0.1` so nobody can go around Tailscale.
   - behind Cloudflare Access: the `Cf-Access-Jwt-Assertion` token, always verified against the team's public keys and the app's audience tag. Never the email header or cookie alone.
   - `signup`: the app's own session.
3. If the setting and the gate disagree (`team`, but no valid token arrives), refuse every request with a plain message. Never fall open.
4. Anything stored per person records whose it is from day one, even when it's always James. Moving to `team` or `signup` then needs no data migration.
5. "Who is this" and "what may they do" are separate. Start with "anyone let in may do everything". Add roles only when the plan names them, in one module.
6. Changing level: update the gate, change `ACCESS` and `PROJECT.md`, redeploy, run the access check. The first move to `signup` is the exception: it adds account screens and emails, and gets its own plan.
7. Never share through passwords, secret links or "anyone with the link". Never use Cloudflare's "Everyone" or "Bypass", or allow anyone who can receive a one-time PIN, on a `private` or `team` app.
8. Apps on jl-platform are reachable only through Cloudflare, so the gate can't be skipped by visiting the server directly.
9. The plan states the starting level and whether `signup` is likely. `PLACEMENT.md` decides the domain.
10. Open sign-up also needs email confirmation, password reset or Google/Apple sign-in, account deletion, and sign-in rate limits, each as a `checks.md` item.

## Checked by scripts

- No identity is refused (unless `public`), a forged header is refused, a valid identity gets in, and `access:` matches what's deployed: `scripts/access-check.mjs`, before going live.
