# Example 1 — Lean: four scenarios, a refused 99.99% and no DORA targets (simplest case)

Self-contained. **Toolshed** is a tool-loan tracker one volunteer is building for a 60-member community makerspace, replacing a shared spreadsheet. The product runs at the **lean** profile, where `phase-requirements.json` requires the NFR specification but keeps it "short — only the NFRs that change a design decision". There is no functional requirements document at lean: the quality concerns and business rules sit in the requirements header of `ideate/user-stories.md`.

## Input

> **Requirements header (ideate/user-stories.md):** BR-1 a loan is due 7 days after it starts; BR-2 a member 7+ days overdue cannot borrow again. TR-4: the Google Sheet is made read-only and archived after a one-week parallel run. **Quality concerns for the NFR specification:** the overdue list must be readable on a phone in the workshop (usability); member names visible only to stewards (privacy).
>
> **User:** "I read that serious apps target 99.99% uptime and elite DORA metrics: deploy on demand, lead time under an hour, change failure rate under 15%. Put those in. I host it on a single small cloud VM and I'm the only developer."

## Working it

- **Consume the hand-off.** Two quality concerns (usability, privacy) and two rules. BR-1 and BR-2 are functional rules (the stories' acceptance criteria test them); neither asks the system to prove anything measurable, so no obligation row.
- **99.99% is a copy-paste target.** About 53 minutes of downtime a year, on one VM run by a volunteer, for a workshop open three evenings and Saturday. Nothing depends on it: stewards can lend on paper for an hour. What *does* matter is that the loan history is never lost once the sheet is retired (TR-4): that changes a design decision (backups). 99.99% is recorded as the user's wish, not a target.
- **The DORA figures are not NFRs.** They are rates of a team's delivery process, and *Accelerate* itself treats its clusters as directional. For one volunteer, the product property that matters is deployability: a fix goes out with one command and can be rolled back. No process targets at lean unless the user still wants them after the explanation; `dora-metrics` holds the clusters if they do.
- **Walk the ten characteristics, keep four scenarios**: each changes a design decision.
- **Conflict check** on the four: the steward wants the overdue list fast on a phone; privacy wants names behind a sign-in. A candidate trade-off point for the user.

## Output — the reply, and `ideate/nfr-specification.md`

> I've kept four NFRs: the ones that change how Toolshed is built. I haven't set 99.99% uptime: it would cost far more than the workshop needs, and a steward can lend on paper for an hour. What can't happen is losing the loan history once the spreadsheet is retired, so there's a recovery target instead. The DORA figures measure how a team delivers, not how the product behaves, so they aren't NFRs; I've written a deployability requirement instead (one-command release and rollback). If you still want delivery targets, `dora-metrics` has the calibration and we'd set values you choose.

```markdown
---
name: nfr-specification
product: toolshed
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-12-02
summary: Toolshed's four design-shaping quality attributes — steward phone use, member-name privacy, no loss of loan history, one-command release — at lean minimums.
profile: lean
status: draft
linked-frd: ideate/user-stories.md (requirements header; lean has no FRD)
traces_to: ideate/user-stories.md (quality concerns, BR-1, BR-2, TR-4); strategy/okrs.md (KR-1.1)
architecture-handoff: [NFR-SEC-01, NFR-REL-01, NFR-DEPLOY-01]
---

# Non-Functional Requirements — Toolshed

**Translation.** The backlog header's two quality concerns and TR-4 become four lean scenarios for the Design phase and the stewards' acceptance walkthrough.

Targets are Planguage **Must** values (the minimum acceptable); lean sets no Plan or Stretch. Planguage *Must* is not a MoSCoW priority.

## Inputs Consumed

| Input | Says (cited, not restated) | Became |
|---|---|---|
| Quality concern 1 | Overdue list readable on a phone in the workshop | NFR-USE-01 |
| Quality concern 2 | Member names visible only to stewards | NFR-SEC-01 |
| TR-4 | Sheet retired after the parallel run | NFR-REL-01 (the tool becomes the only record) |
| BR-1, BR-2 | Loan period; overdue block | No NFR: functional, tested by the stories' acceptance criteria |
| User's 99.99% | — | Not a target: recorded as a wish (see Ranking) |

## Characteristics Considered

| Characteristic | Decision |
|---|---|
| Functional suitability | Declined: the stories' acceptance criteria own it |
| Performance efficiency | Declined: 60 members, a few dozen loans a week; any reasonable design is fast enough |
| Compatibility | Declined: no integrations (the sheet import is one-off, TR-1) |
| Interaction capability | Kept: NFR-USE-01 |
| Reliability | Kept: NFR-REL-01 (recoverability). Uptime declined: paper fallback exists |
| Security | Kept: NFR-SEC-01 (confidentiality) |
| Maintainability | Declined: one developer, small codebase |
| Flexibility | Declined: one makerspace, no growth planned this year |
| Safety | Declined: tool safety inductions happen in person, outside the product |
| Deployability | Kept: NFR-DEPLOY-01 |

## Ranking

1. **NFR-SEC-01**: decides that the app needs sign-in and two roles (member, steward).
2. **NFR-REL-01**: decides that the database is backed up off the VM and restores are rehearsed.
3. **NFR-DEPLOY-01**: decides a scripted release with a kept previous version.
4. **NFR-USE-01**: decides a phone-first overdue list rather than a desktop table.

Wish (not designed for): 99.99% uptime, from the user, 2026-12-02.

## Quality-Attribute Scenarios

| ID | Characteristic | Stimulus | Environment | Response measure | Traces to | Verification |
|---|---|---|---|---|---|---|
| NFR-USE-01 | Interaction capability (operability) | A steward looks up who has an overdue tool | Saturday session, standing in the workshop, own phone, unaided | Finds the member and the due date within 30 s in 4 of 5 tries (Must) | Quality concern 1; JS-2.1 | Timed walkthrough with both stewards at TR-3 |
| NFR-SEC-01 | Security (confidentiality) | A signed-in member who is not a steward opens the overdue list or another member's loans | Normal operation | Refused in 20 of 20 attempts; only tool status and due date shown (Must) | Quality concern 2 | Scripted access test per release |
| NFR-REL-01 | Reliability (recoverability) | The VM's disk is lost | Any time after the sheet is retired | Loans restored from backup; at most 24 h of loans lost (RPO, Must); restored within 2 days (RTO, Must; stewards lend on paper meanwhile) | TR-4 | Restore rehearsal before go-live, then every 3 months |
| NFR-DEPLOY-01 | Deployability | The volunteer has a fix ready | Normal operation, outside session hours | Released with one command; rolled back to the previous version within 15 min with no loan data lost (Must) | Product property | Rehearse a release and a rollback before go-live |

## Obligations from Business Rules

None: BR-1 and BR-2 are functional and require nothing measurable of the system beyond their acceptance criteria.

## Candidate Trade-off Points

| ID | Scenarios | Why they pull apart | Options open (not chosen) | Decided by |
|---|---|---|---|---|
| TP-1 | NFR-USE-01 × NFR-SEC-01 | Signing in on a phone every session slows the steward; staying signed in exposes names if the phone is lost | A long steward session with a phone PIN; a short session with a magic link | The user |

## Derived Requirements

| From | Functional requirement sent to the backlog | Status |
|---|---|---|
| NFR-SEC-01 | Stewards and members have different views (steward role) | Story US-6 added |

## Process Targets

None set (lean; the user was told the DORA figures are process targets and can choose values from `dora-metrics` later).

## Architecture Handoff

| NFR | Rating (value, impact) | Trade-off points | Tactic families (pointers only) |
|---|---|---|---|
| NFR-SEC-01 | (H, H) | TP-1 | Authenticate and authorise actors |
| NFR-REL-01 | (H, H) | — | Recover from faults: backup and restore |
| NFR-DEPLOY-01 | (M, H) | — | Script deployment; keep the previous version for rollback |

## Open Questions

None.
```

## Why this is right at lean

| Choice | Reason |
|---|---|
| Four scenarios, Must only | Lean minimums; each changes a design decision |
| Every characteristic has a line | Declines are visible and arguable, not forgotten |
| 99.99% kept as a wish | No business driver; recovery of the only record is what matters |
| No DORA targets; one deployability scenario | Process rates are not product qualities; the release mechanism is |
| Short form, but the environment is never dropped | "Saturday, standing in the workshop, own phone" is what makes NFR-USE-01 testable |
| Trade-off left to the user | The NFR names the tension; it does not choose |
