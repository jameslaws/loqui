---
playbook: v5.2.2
skills: [core, crew, planning, testing, code-standards, checkpoint, shipping, stack-guide, access, accessibility, design-slot, playbook]
access: private            # private | public | team | signup
design: proposed-in-plan   # or james-design, ninja-design-system
staging:                  # decided in its first plan
production:               # decided in its first plan
signed_in_page: /          # the page live-check loads signed in
branches:
  staging: main
  production: main
---

# Loqui

One or two sentences: what it is, and who it's for.

## Who it's for

The access level above, in words, and whether open sign-up is likely later.

## Stack

The stack guide's defaults this project uses, and anything it does differently with the reason.

## Where it runs

- Staging: address, host, and where its data comes from (scrubbed or made up).
- Production: address and host.

## How it ships

- What deploys staging and production, and what has to pass first.
- How to return to the last working release.
- Database changes: where migrations live, and the backup and restore routine.

## Commands

`dev`, `check`, `check:changed`, `test:acceptance`, `test:contracts`, `start`, plus anything unusual.

## Project rules

Rules only this project needs, one line each, with the reason where it isn't obvious. A rule that a second project also learns becomes a playbook proposal (see the `playbook` skill).

-
