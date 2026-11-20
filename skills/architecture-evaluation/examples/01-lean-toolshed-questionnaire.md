# Example 1 — Lean: A Volunteer-Built Tool Loan Tracker Asking for "a Full ATAM"

Self-contained. **Toolshed** is a tool-loan tracker one volunteer is building for a 60-member community makerspace, on a single small cloud VM, at the **lean** profile. The NFR specification's Architecture Handoff lists three scenarios rated high on architectural impact: **NFR-SEC-01** (a member who is not a steward must be refused the overdue list: refused in 20 of 20 scripted attempts), **NFR-REL-01** (after losing the VM's disk, loans restored from backup, at most 24 hours lost, restored within 2 days) and **NFR-DEPLOY-01** (released with one command, rolled back to the previous version within 15 minutes with no loan data lost). The design is a modular monolith with a sign-in and two roles, a nightly backup to object storage off the VM, and a scripted release that keeps the previous version.

## Input

> **User:** "Run a full ATAM so we're covered, and write 'independently reviewed' in the record so the makerspace board is comfortable."

## Working it

- **A full ATAM is declined.** It needs many stakeholders, an outside evaluation team and several days. Here one agent designed the architecture and one volunteer approves it. What fits a lean product is the **lightweight in-house evaluation**: a tactics questionnaire on the top two or three scenarios.
- **"Independently reviewed" is declined.** The designing agent is evaluating its own design, so the record says it is a **self-check, not independent, and not an ATAM**. Anything else would mislead the board.
- **Scenarios** come from the NFR handoff and are not changed here. All three are evaluated (the lean limit is the top two or three).
- **Findings.**
  - NFR-REL-01: the nightly backup serves the 24-hour RPO, but **restores are never rehearsed**, so the 2-day RTO is unproven. That is a **risk** (R-1). The NFR already asks for a rehearsal before go-live; the action is to schedule it.
  - NFR-SEC-01: sign-in with two roles and a role check on the overdue list is a **non-risk**, with the reason that the check sits on the single data path every request takes.
  - NFR-DEPLOY-01: a scripted release that keeps the previous version is a **non-risk**; the rollback is the previous version.
  - No sensitivity or trade-off point was met at this size, so none is invented. No risk themes at lean.
- **Fitness functions worth having:** the scripted access test per release (NFR-SEC-01) and a quarterly restore rehearsal as a scheduled job (NFR-REL-01).

## Output: `artifacts/toolshed/design/architecture/architecture-evaluation.md` (frontmatter omitted in a reply)

````markdown
---
name: architecture-evaluation
product: toolshed
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-20
summary: Lean self-check of Toolshed's top three scenarios: one risk (restores never rehearsed) and two non-risks.
traces-to: [ideate/nfr-specification.md, design/architecture/container-diagram.md]
self-check: true
---

# Architecture Evaluation for Toolshed

**Readers:** enterprise-architect, the product owner, backend-engineer
**Question it answers:** does the design, as it stands, meet its highest-impact scenarios, and where does it not, or only at a cost?

- **Profile:** lean
- **Self-check:** This is a self-check by the agent that designed the architecture: not independent, and not an ATAM (a full ATAM needs many stakeholders, an outside team and several days).

## Scenarios Evaluated

| Scenario | Rating (value, impact) | Response measure | Approaches that serve it |
|---|---|---|---|
| NFR-SEC-01 | (H, H) | refused in 20 of 20 scripted attempts | sign-in, two roles, a role check on the overdue list |
| NFR-REL-01 | (H, H) | at most 24 h of loans lost; restored within 2 days | nightly backup to object storage off the VM |
| NFR-DEPLOY-01 | (M, H) | released with one command; rolled back within 15 min | scripted release that keeps the previous version |

## Tactics Questionnaire

| Scenario | Tactic family | Question | Answer | Where in the design |
|---|---|---|---|---|
| NFR-SEC-01 | resist attacks | are actors authenticated and authorised? | yes | sign-in and the steward role check |
| NFR-REL-01 | recover from faults | is there a restore path from a lost disk? | partial | the nightly backup; the restore is never rehearsed |
| NFR-DEPLOY-01 | manage the pipeline | is deployment scripted with a rollback? | yes | the release script keeps the previous version |

## Risks

| ID | Scenario | Decision | Why it may fail | Action |
|---|---|---|---|---|
| R-1 | NFR-REL-01 | restores from the backup are never rehearsed | an untested restore may take longer than the 2-day measure | run a restore rehearsal before go-live, then every 3 months |

## Non-Risks

| ID | Scenario | Decision | Reason it is safe |
|---|---|---|---|
| N-1 | NFR-SEC-01 | a role check on the overdue list | every request takes that one data path, so a missing check would show in the scripted access test |
| N-2 | NFR-DEPLOY-01 | a scripted release that keeps the previous version | the rollback is the previous version, so it needs no data change |

## Fitness Functions

| Characteristic | Rule that must stay true | Check | Where it runs | Owner |
|---|---|---|---|---|
| confidentiality | a non-steward is refused in every scripted attempt | the scripted access test | every release build | backend-engineer |
| recoverability | a restore completes within 2 days | a restore rehearsal job | every 3 months, scheduled | platform-engineer |

## Actions

- Schedule the first restore rehearsal before go-live; owner: the volunteer developer.

## Open Questions

- Whether the board wants a written summary of the rehearsal result; owner: product owner.
````

> **Reply summary:** a full ATAM is declined because it needs many stakeholders, an outside team and days; this is a lightweight self-check by the designing agent, not independent and not an ATAM, and the record says so rather than "independently reviewed"; the scenarios come from the NFR handoff; one risk (restores never rehearsed) and two non-risks with reasons; two fitness functions; no risk themes at lean; no implementation code.
