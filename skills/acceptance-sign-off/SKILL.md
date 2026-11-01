---
name: acceptance-sign-off
description: >
  Teaches how to record the acceptance decision that closes Customer
  Validation for a release: full sign-off, conditional sign-off or no-go,
  decided by the accepting authority against evidence compiled from the UAT
  plan's completion summary, scenario results (Pass / Fail / Blocked / Not
  run), exploratory debriefs, triaged feedback, the other acceptance types in
  scope (operational, contractual, regulatory) and beta graduation. Owns the
  single defect rule (what an open Critical, High, Medium or Low defect
  allows), the two-party authority and the solo-operator exception, residual
  risk, the repeatability check, dated conditions with owner, workaround and
  re-test, one sign-off per release, and the rollout action it hands to
  canary-deployment and feature-flag-design. Use when deciding go / no-go,
  asking whether a release can ship with an open defect, signing off alone,
  handling a customer representative who will not accept, accepting some
  tenants but not others, or re-attempting after a no-go. Used by the
  requirements-analyst agent last in Customer Validation (/sdlc-validate);
  written to customer-validation/sign-off/<release>.md.
version: 3.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [customer-validation, sign-off, go-no-go, acceptance-decision, defect-rule, residual-risk, test-independence, canary, release-gate]
produces: acceptance-sign-off-record
domain: validation
status: stable
related: [uat-plan, uat-scenario, feedback-template, beta-program-design, canary-deployment, feature-flag-design, compliance-verification, glossary-management, methodology-review]
sources:
  - research/testing/user-acceptance-testing-hambling.md
  - research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md
  - research/testing/agile-testing-crispin-gregory.md
  - research/testing/explore-it-hendrickson.md
  - research/human-ai-collaboration/co-intelligence-mollick.md
---

# Acceptance Sign-Off

## Purpose

The sign-off answers one question so it cannot be quietly reinterpreted later: **does this release widen to everyone, widen with conditions, or not widen at all?** Hambling and van Goethem (*User Acceptance Testing: A Step-by-Step Guide*) put the purpose of acceptance testing plainly: give the business enough confidence to **decide**. Finding defects is a side effect. This record is the decision, made by the people who will live with the system, against criteria agreed before execution.

The release is already running on a canary or behind a flag. The sign-off is what lets it **widen**. It is the only artifact that authorises `canary-deployment` to go to 100% or `feature-flag-design`'s release flag to reach the full fleet.

| Owned here | Owned elsewhere |
|---|---|
| The decision and its record; **the single defect rule**; who may sign; the solo-operator Exception block; residual risk; conditions; the rollout action | Scope, roles, exit criteria and the completion summary: `uat-plan` · scenario results: `uat-scenario` · severity scale and triage: `feedback-template` · stage graduation: `beta-program-design` · executing the rollout: `platform-engineer` |

## 1. Compile the Evidence, Then Decide

The decision **cites** the evidence; it is never a separate impression (Hambling). Start from `uat-plan`'s completion summary (planned vs run, results, open defects, residual risk, recommendation) and confirm each line of `./resources/sign-off-checklist.md`. In short:

- every Must scenario has a result, and **none is Blocked or Not run**: a blocked scenario is not a pass;
- the pass threshold agreed **before** execution is met; a threshold changed after the results is recorded as a decision in its own right, never a silent edit;
- every planned exploratory session ran and was debriefed, its findings triaged like any scripted failure (Hendrickson, *Explore It!*: exploration finds what no scenario was written for; Crispin and Gregory, *Agile Testing*: Q3 findings feed the decision);
- **every acceptance type in scope has a result**: OAT, contractual, regulatory, each accepted by its own signatory;
- open defects sit within the defect rule (§ 2); all feedback triaged; no unaddressed blocking pattern;
- **repeatability**, when there was more than one executor or cohort: were they all set up the same documented way? Blank (*The Four Steps to the Epiphany*) defines Customer Validation by repeatability. Three passes that each needed bespoke hand-holding are weaker evidence than they look: record it as residual risk;
- **residual risk written down**: what is knowingly accepted, and by whom (ISTQB).

An unchecked item does not decide the outcome by itself. The authority decides how to handle it, and the record says so.

## 2. The Defect Rule

This is the **one** statement of what open defects allow. `uat-plan`, `uat-scenario`, `beta-program-design` and the requirements-analyst point here and never restate it. Severity is `feedback-template`'s, set at capture and never bargained down.

- **An open Critical defect → no-go**, always.
- **An open High defect → conditional sign-off only, and only with a fix plan**: owner, target date, a workaround a business user can follow, the re-test that will verify the fix, and the rollout pace meanwhile. An open High with no fix plan → no-go.
- **Open Medium and Low defects → conditional or full**, at the authority's judgment. Each one accepted is listed under residual risk, rated, with a workaround where a user needs one and the release it is scheduled for (Hambling: accepting known defects is normal; accepting them *implicitly* is not).
- **A confirmed blocking pattern** (`feedback-template`: most participants independently hitting the same friction on a Must flow) is treated as High, even when each report is Medium.

When asked "can we still ship with this open?", answer with the whole rule, every severity, not only the one asked about.

## 3. Who Signs

**Two parties by default.** The **product owner** is accountable for the business decision. A **customer representative** (a named person at the design partner or customer, by role) confirms the release is usable from their side. Acceptance means the accepting party's affirmative agreement, so an internal decision to ship is not acceptance.

**Other acceptance types bring their own signatory.** Regulatory: a named compliance signatory, against `compliance-verification` attestations. Contractual: the contract's signatory, per clause. OAT: the product owner, on `platform-engineer`'s evidence.

**Several customers, several cohorts.** At enterprise each customer representative accepts for **their own** tenant cohort. One refusal keeps that cohort out of the widening: the release is at most conditional, and that cohort's re-attempt (a new UAT pass and their signature) is an **addendum** to this record, not a second sign-off.

**Solo-operator exception (D045).** When the product owner is the only person who can execute and accept, they sign alone and the record carries an `## Exception: solo operator` block, in the same words as `uat-plan`: who executed, who accepted, **independence level "none"** (ISTQB), why no second party was available, the per-scenario evidence, and any borrowed session. **A full sign-off is allowed**; the exception carries the risk. Never cap the outcome at conditional because of it, and never sign alone without the block.

**A human signs.** Mollick (*Co-Intelligence*): the human stays the point of final judgment, not a rubber stamp. The agent compiles evidence and drafts; it never records a signature on a person's behalf, and it is never the independent party. Each signature records the date and how it was given.

## 4. Three Outcomes

| Outcome | When | The record must carry |
|---|---|---|
| **FULL SIGN-OFF** | No open Critical or High; every Medium or Low accepted is listed as residual risk | Rollout to GA |
| **CONDITIONAL SIGN-OFF** | No open Critical; any open High has its fix plan; or a scope or cohort is held back | Each condition: issue, severity, workaround, owner, target date, re-test; the rollout pace meanwhile |
| **NO-GO** | An open Critical; a High with no fix plan; an unaddressed blocking pattern; or the customer representative does not accept, whatever the checklist says | Each blocking item and what must change; re-attempt = a **new UAT pass**, never a re-review of the same evidence |

A conditional sign-off is acceptance *with concessions*: each concession is named, rated and time-bound. It is a legitimate, common outcome, not a weaker full. A no-go is the process working: a gate that can say no is what makes a yes mean something. The conditional's re-verification, a missed target date, and the no-go re-attempt: `./references/outcomes-and-rollout.md`.

## 5. One Sign-Off per Release, and the Rollout It Triggers

There is **one sign-off per release**, at the close of Customer Validation. Its rollout action states the whole path to GA. Beta stage moves (closed → open beta → GA) are graduation records in `beta-program-design`, not further sign-offs. A conditional sign-off **may reach 100%** with its conditions tracked. Customer Validation re-opens, with a new UAT pass and a new sign-off that supersedes this one, only when widening surfaces a new Critical or High, a graduation fails, or a representative withdraws.

| Outcome | `canary-deployment` | `feature-flag-design` release flag |
|---|---|---|
| Full | Widen to 100% and terminate | Removed at (or before) its `removal_date` |
| Conditional | Widen at the stated pace: to 100%, or hold at a named stage until a condition closes | Scope widens to match; not removed until conditions close |
| No-go | Hold, or revert to 0% | Stays scoped to the validation cohort, or reverts to off |

The requirements-analyst decides; `platform-engineer` operates the mechanism. No agent widens a canary or a flag to GA without this record. Per-cohort rollout, stage paths and the hand-off: `./references/outcomes-and-rollout.md`.

## Scale

`phase-requirements.json`: `acceptance-sign-off` is **required at every profile**, at `customer-validation/sign-off/<release>.md`.

| Profile | Shape |
|---|---|
| **lean** | One page; usually the solo-operator exception; UAT plus the three-line OAT smoke; rollout = the flag to everyone. `./examples/01-lean-solo-full.md` |
| **standard** | Two-party; design-partner evidence on a canary; repeatability line; dated conditions. `./examples/02-standard-conditional-high.md` |
| **enterprise** | A signatory per acceptance type; a representative per tenant cohort; per-cohort rollout and addenda. `./examples/03-enterprise-split-cohorts.md` |

## Producing the Sign-Off

1. **Scaffold**: `bash ./scripts/scaffold-signoff.sh <product> <release>` copies `./templates/acceptance-sign-off.md` to `artifacts/<product>/customer-validation/sign-off/<release>.md` with today's date and the checklist unchecked.
2. **Compile** the evidence from `uat-plan`'s completion summary, the scenario results, the feedback log and any beta graduation records; tick only what the evidence shows (§ 1).
3. **Apply the defect rule** (§ 2) and draft the outcome (§ 4); name the signatories or fill the Exception block (§ 3).
4. **Present it to the user.** Every conditional's fix plan and dates need the user's explicit approval; the customer representative's agreement is theirs to give, not the agent's to assume.
5. **Validate**: `bash ./scripts/validate-signoff.sh <path>` checks structure only (signatories or a filled Exception, one valid decision, no open Critical under a sign-off, conditions with owner and date, a High condition with workaround and re-test, residual risk and rollout stated). It never judges acceptability. Cross-check `./resources/sign-off-checklist.md` by hand.
6. **Hand off** the rollout action to `platform-engineer`; track each condition to its re-test.

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Unilateral sign-off** | An internal decision to ship labelled as acceptance, with no representative and no Exception block |
| **A no-go relabelled conditional** | Defeats the gate; an open Critical is no-go |
| **Silent conditional-to-full drift** | Conditions quietly expire once shipped; the re-test and date are part of the record |
| **Blocked counted as passed** | Overstates readiness |
| **Yardstick moved after the results** | An acceptance decided against criteria changed afterwards is a negotiation |
| **Re-attempt on old evidence** | "Fixed" means deployed, not proven; a no-go re-attempt needs a new UAT pass |
| **Exploratory findings off the record** | Reintroduces the blind spot the sessions exist to close |
| **The agent signs or assumes agreement** | No human judgment in the loop |
| **A second defect rule elsewhere** | Two rules drift; this skill holds the only one |
| **A sign-off per beta stage** | Duplicates the decision; stage moves are graduation records |

Use canonical terms from `glossary-management`: **Acceptance Testing**, **User Acceptance Testing**, **Operational Acceptance Testing**, **Test Independence**, **Exit Criteria**, **Residual Risk**, **Canary Deployment**. Run `methodology-review` before hand-off.
