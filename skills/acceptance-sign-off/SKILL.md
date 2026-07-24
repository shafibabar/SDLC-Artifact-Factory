---
name: acceptance-sign-off
description: >
  Teaches how to produce the formal go/no-go artifact that closes Customer
  Validation — the sign-off criteria checklist (including exploratory
  session findings alongside scripted UAT results), the two-party sign-off
  authority (Shafi plus a customer/design-partner representative), the
  distinction between full sign-off, conditional sign-off (with a documented
  remediation plan and target date), and no-go, and this artifact's role as
  the trigger for widening the `canary-deployment` rollout and the
  `feature-flag-design` release flag to General Availability. Includes
  scripts/scaffold-signoff.sh (generates a new sign-off doc pre-filled with
  release-slice metadata and the full checklist) and
  scripts/validate-signoff.sh (mechanically checks the checklist, both
  parties, and a stated decision/rollout action). Used by the
  requirements-analyst during Customer Validation.
version: 2.1.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [customer-validation, sign-off, go-no-go, canary, release-gate]
related: [skill-authoring-standards, uat-plan, feedback-template]
---

# Acceptance Sign-Off

## Purpose

Acceptance sign-off is the formal decision that closes the Customer Validation phase for a release slice. It is the single artifact that answers one question in a way that cannot be quietly reinterpreted later: **does this release proceed to General Availability, proceed with conditions, or not proceed at all?**

Everything upstream in this domain — `uat-plan`'s execution, `uat-scenario` results, `beta-program-design`'s graduation evidence, `feedback-template`'s triaged items — exists to feed this one decision. Acceptance sign-off is not a status update; it is the trigger that widens `canary-deployment` toward 100% and expands the `feature-flag-design` release flag's scope toward the full fleet. Nothing advances past this gate without it.

---

## Sign-Off Criteria Checklist

Before a sign-off decision of any kind can be recorded, the following are verified — this is the evidence base the decision is made against, not the decision itself:

- [ ] Every UAT scenario tracing to a Must Have story has a recorded result (`uat-plan`, `uat-scenario`)
- [ ] The UAT pass-rate threshold stated in the `uat-plan` is met
- [ ] Every planned exploratory session has been run and debriefed (`uat-plan`'s Exploratory Testing Component) — a separate check from the pass-rate threshold, since a charter has no pass/fail; its findings are triaged into this checklist exactly like a scripted defect
- [ ] Zero open Critical severity defects (`feedback-template`) — from either scripted UAT or exploratory sessions
- [ ] Zero open High severity defects, **or** each is covered by a documented remediation plan with a target date (conditional path only — see below)
- [ ] All feedback items have been triaged (`feedback-template`) — none left unreviewed, whether sourced from a scripted scenario or an exploratory debrief
- [ ] No unaddressed blocking pattern exists — a pattern (`feedback-template`'s aggregation discipline) that, even at Medium severity, represents a majority of participants independently reporting the same friction on a Must Have flow is treated as blocking unless explicitly accepted with rationale
- [ ] Beta program graduation criteria met for the relevant stage, if this release slice is progressing through `beta-program-design` stages

A checklist item left unchecked does not automatically mean no-go — it means the sign-off authority must explicitly decide how to handle the gap, recorded in the decision itself.

---

## Sign-Off Authority — Two-Party, Never Unilateral

| Party | Role |
|---|---|
| **Shafi** | Product owner — accountable for the business decision to ship |
| **Customer/design-partner representative** | The named contact from the participating design partner (e.g., Maya Chen) — accountable for confirming the release is genuinely usable and acceptable from the customer's side |

Both parties review the compiled evidence and both must agree for a sign-off (full or conditional) to be recorded. This is deliberate: a unilateral internal decision to ship is not "acceptance" — acceptance, by definition, requires the accepting party's affirmative agreement. If no design-partner tenant participated in this release slice (an internal-proxy-only UAT per `uat-plan`), the sign-off cannot be full — it is capped at conditional, with the specific limitation ("validated by internal proxy only, no external design-partner confirmation") stated as one of the open conditions.

This two-party, never-unilateral rule is this repo's clearest product-facing instance of keeping a human as the actual point of final consent (per Ethan Mollick's *Co-Intelligence*, `research/human-ai-collaboration/co-intelligence-mollick.md`) — the same principle `CLAUDE.md`'s own Session Startup gate applies to *this repo's* engineering work. No amount of green dashboards, passing scripted scenarios, or agent-generated confidence substitutes for an actual person affirming the release is acceptable.

---

## Three Outcomes

### Full sign-off

All checklist items are met with no exceptions. The release proceeds to GA with no outstanding conditions.

```
Decision: FULL SIGN-OFF
Rollout action: canary-deployment widens to 100% and terminates;
                 feature-flag-design release flag deleted at its removal_date
                 (or immediately, if its purpose was purely the canary scope)
```

### Conditional sign-off

The Must Have bar is met (zero Critical/High defects blocking the core outcome) but one or more Medium/Low issues remain open, or a scope limitation exists (e.g., internal-proxy-only validation). The release proceeds, paired with an explicit, dated remediation commitment.

```
Decision: CONDITIONAL SIGN-OFF
Conditions:
  - [Issue] — remediation plan: [what will be done] — target date: [date]
  - [Issue] — remediation plan: [what will be done] — target date: [date]
Rollout action: canary-deployment widens per the plan's stated pace (may still
                 reach 100%, or may hold at a lower stage pending remediation —
                 stated explicitly, not left ambiguous)
Follow-up: remediation tracked; re-verification required by target date
```

A conditional sign-off is a legitimate, common outcome — it is not a weaker or embarrassing version of full sign-off. It exists precisely so that Medium/Low findings don't either get silently ignored (shipping with no record) or block a release that genuinely delivers its Must Have value.

### No-go

A Critical or High severity defect remains open with no acceptable remediation plan, or an unaddressed blocking pattern exists on a Must Have flow, or the customer representative does not agree the release is acceptable regardless of the internal checklist status.

```
Decision: NO-GO
Blocking items:
  - [Defect/pattern] — required remediation before re-attempt: [what must change]
Rollout action: canary-deployment holds or reverts to 0% for this release
                 (per canary-deployment's rollback mechanics); feature-flag-design
                 release flag stays false beyond the validation cohort
Re-attempt: Customer Validation re-opens for this release slice once blocking
             items are remediated; a new UAT pass is required, not a re-review
             of the same evidence
```

A no-go is not a failure of the process — it is the process working. The gate existing to sometimes say no is what makes a "yes" mean something.

---

## Trigger for GA Rollout

Acceptance sign-off is the only artifact authorized to trigger the final rollout actions:

| Sign-off outcome | Canary action (`canary-deployment`) | Flag action (`feature-flag-design`) |
|---|---|---|
| Full | Widen to 100%, terminate rollout, canary Deployment becomes stable | Release flag deleted at (or ahead of) its removal_date |
| Conditional | Widen per the explicitly stated plan — may reach 100% with remediation tracked separately, or hold at an intermediate stage pending a Medium/High fix | Release flag scope widens to match the stated rollout pace; not deleted until conditions close |
| No-go | Hold or revert to 0% | Release flag remains scoped to the validation cohort only, or reverts to `false` |

No agent widens a canary rollout or a release flag's scope to GA without a recorded sign-off artifact — this keeps the human decision, not a schedule or a dashboard-green status, as the actual gate.

---

## Worked Example

Full worked example — a conditional sign-off incorporating both scripted
UAT results and exploratory-session findings: `references/worked-example.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Checklist evidence-based | Every checklist item cites its source (`uat-plan`, `feedback-template`, `beta-program-design`) | Checklist items asserted without a traceable source |
| Exploratory findings included | Exploratory-session results are checked and triaged alongside scripted UAT results, not treated as optional | A sign-off recorded while planned exploratory sessions never ran, or their findings were never triaged |
| Two-party authority | Both Shafi and a customer/design-partner representative are named and recorded as agreeing | A unilateral internal decision recorded as "sign-off" |
| Correct outcome category | Full/Conditional/No-go matches the actual defect/pattern status per the decision rules | A release with an open Critical defect recorded as full or conditional sign-off |
| Conditions are dated and owned | Every conditional item has a remediation plan, an owner, and a target date | Vague "we'll fix it later" with no owner or date |
| Rollout action explicit | The canary/flag action following the decision is stated, not implied | Sign-off recorded with no stated effect on the rollout |
| No-go triggers re-validation | A no-go explicitly requires a new UAT pass on re-attempt, not a re-review of old evidence | Blocking items "fixed" and shipped without re-running UAT |

---

## Anti-Patterns

**Unilateral sign-off.** Shafi alone deciding to ship, without the customer/design-partner representative's affirmative agreement, is not acceptance — it is an internal release decision wearing the wrong label. If no design partner participated, the outcome is capped at conditional, with that gap stated explicitly.

**Silent conditional-to-full drift.** Treating a conditional sign-off's remediation items as optional once the release has shipped — the tracked follow-up (target date, re-verification) is part of the sign-off record, not a suggestion that quietly expires.

**No-go treated as a process failure to route around.** Re-labeling a no-go as "conditional" to avoid halting the rollout defeats the purpose of the gate; the checklist and decision rules exist precisely to make a no-go possible when it's warranted.

**Sign-off as a rubber stamp.** Recording "full sign-off" without the underlying checklist evidence attached turns the artifact into a formality instead of a decision — the checklist and its sources must be visible in the same document.

**Skipping re-validation after remediation.** Assuming a fix works because it was deployed, without re-running the specific UAT scenario or re-checking the pattern, converts "remediated" into an untested claim — exactly the gap the whole Customer Validation phase exists to close.

**Exploratory findings treated as informal, off-the-record chatter.** A finding surfaced during an exploratory session (`uat-plan`) is exactly as real as a scripted scenario's failure — it goes through the same `feedback-template` triage and the same checklist evidence requirement. Recording a sign-off decision without checking whether planned exploratory sessions actually ran and were debriefed reintroduces exactly the blind spot the sessions exist to close.

---

## Scripts

Per `skill-authoring-standards`, this skill owns two deterministic scripts — neither decides *whether* a release is acceptable, only whether the sign-off record is structurally complete, leaving the actual go/no-go judgment to the two named parties.

| Script | Does | Run when |
|---|---|---|
| `scripts/scaffold-signoff.sh <product> <release-slice>` | Copies `assets/sign-off-template.md`, fills in the release-slice name and today's date, writes a new sign-off doc under `artifacts/[product]/customer-validation/sign-off/` with the full Sign-Off Criteria Checklist copied in unchecked | Starting the sign-off record for a release slice, once `uat-plan` execution and any exploratory sessions have run |
| `scripts/validate-signoff.sh <path>` | Checks the Sign-Off Criteria Checklist section is present, both sign-off parties are named (not still bracketed placeholders), the Decision line names exactly one of the three valid outcomes, and a Rollout Action is stated | Before treating a sign-off record as final |

---

## Output Format

Fill-in-and-go: `assets/sign-off-template.md` (or generate it directly via `scripts/scaffold-signoff.sh`). Annotated template explaining each field: `references/output-format-template.md`. Mechanical check before treating a sign-off as final: `scripts/validate-signoff.sh`.
