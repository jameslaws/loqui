---
name: shipping
description: How work moves from a feature branch to staging to production, and what "live" means. Use when merging, deploying, promoting an approved version, rolling back, or reporting that something is live.
metadata:
  applies_to: all
  version: "2"
---

# Shipping

Short feature branches merge to staging; James's approval of one exact staging version is what ships it. Agents ship and verify. James never gets a "please merge, deploy or test this" chore.

## Branches and staging

1. Feature branches are short-lived and merge into the staging line when green. `PROJECT.md` records each project's branch for staging and for production.
2. The Lead merges with `merge-pinned` at the reviewed full head SHA. Default is merge-when-green. Batch into one merge train only when 3 or more green changes are waiting or each deploy costs money; then check the combined result and land exactly those heads.
3. Once a PR is marked ready, push nothing more to it. New work restarts review.
4. Staging and production deploy themselves from their branch, only after checks pass. A failed deploy leaves the old release running. Never deploy from a worktree or copy files onto a server by hand.
5. Staging holds only scrubbed or made-up data, so agents check it freely without approval. A copy of production with every personal detail replaced counts as scrubbed; the scrub job is the only way production data reaches staging. Only production is gated.
6. Staging is separate from production: its own data, credentials and outgoing mail. Staging never sends to real people.
7. Preview and staging addresses are never public: gate them as `private` or `team`, even for a public project.
8. Deploys never ship `plans/` or docs.

## Data

9. Database changes only add: new tables, new optional columns. Removing or rewriting data needs its own plan step and a tested backup.
10. A code rollback doesn't undo data changes or messages already sent. Never improvise a destructive database rollback.

## Going to production

11. Only the Shipper promotes, through `ship-guard`: exact approval, commit, build, lockfile, plan and checklist revisions; one use.
    Its fixed deployment policy owns receipt storage and the build-id promotion adapter. Production waits for authenticated approval capture (`checkpoint`).
12. Before every production ship, run `safety ship <project> --commit <sha>` (agent-pipeline): it stops a risky plan without a finished Codex review, then takes a snapshot or records the restore point, and Aiva shows which on the Shipped row.
13. Before promoting: know the last working release and how to return to it, and confirm the data changes are compatible with it.
14. Don't deploy during a long run or an email send.
15. Feature switches let James try finished work. They never hide half-built work.

## Live

16. "Live" means `live-check` loaded the real, signed-in production page and saw the deployed commit. Merged isn't live; a green deploy log isn't live.
17. Report "live" only after that, with the evidence link.
18. If the check fails: return to the last working release when safe, alert the Lead, and keep the work marked unshipped.

## Checked by scripts

- The signed-in page and deployed commit after every deploy, staging and production: `scripts/live-check.mjs`.
- Dangerous session commands: `scripts/command-guard.mjs`; committed credentials: `scripts/secret-scan.mjs`.
- Destructive database changes: `scripts/additive-migrations.mjs`.
- Deploys only from a commit that passed checks: the project's CI and deploy settings, recorded in `PROJECT.md`.
