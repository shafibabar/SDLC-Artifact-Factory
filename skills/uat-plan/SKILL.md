---
name: uat-plan
description: >
  Teaches how to plan User Acceptance Testing for the Customer Validation
  phase — deriving UAT scope from MoSCoW Must Have stories, defining
  participant roles (design partners or an internal proxy as executors, the
  requirements-analyst as facilitator, Shafi plus a customer stakeholder as
  sign-off authority), the canary tenant or staging environment UAT runs
  against, entry and exit criteria, the schedule structure, and — per
  Elisabeth Hendrickson's exploratory testing practice — a time-boxed
  exploratory session component run alongside scripted scenarios, since
  scripted scenarios can only check what someone already wrote down. UAT
  proves a deployed release behaves correctly for real users before wide
  rollout — it is the final human-in-the-loop gate, not pre-deployment QA.
  Used by the requirements-analyst during Customer Validation.
version: 2.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [customer-validation, uat, acceptance-testing, moscow, canary, sign-off, design-partners, exploratory-testing]
---

# UAT Plan

## Purpose

A UAT Plan defines what will be validated, by whom, in which environment, and against what pass/fail bar, before a release is widened from a canary tenant to the full customer fleet. It is the single document that turns "we deployed it" into "a human confirmed it does what we promised, in production conditions" — through **both** scripted scenarios (proving known examples work) and time-boxed exploratory sessions (surfacing what no one wrote a scenario for).

UAT in this plugin is **not** a pre-deployment gate. By the time UAT begins, the release has already passed every Quality-phase gate (automated test suites, `bdd-feature-file` scenarios green in CI, NFR verification) and has already been deployed via `canary-deployment` to a canary tenant or a production-like `environment-config` staging environment. UAT is what happens *after* that — real people exercising the deployed system, under real (or realistic) conditions, before the canary widens to 100% and the rest of the fleet receives the release.

| If you are asking... | You want... |
|---|---|
| "Does the code work, verified by automated tests before merge?" | Quality phase, `test-strategist`, `bdd-feature-file` |
| "Does the deployed release behave correctly for a real user, before we widen the rollout?" | Customer Validation phase, `requirements-analyst`, this skill |

---

## Scope Derivation from MoSCoW Must Haves

UAT scope is never "test everything." It is derived directly from the `moscow-prioritization` artifact's Must Have list for the release slice being validated — a Must Have story that has no UAT scenario is an ungated risk about to ship to the full fleet; a Should/Could Have consuming UAT time is scope creep that dilutes the signal UAT exists to produce.

**Traceability table** — every UAT plan opens with this, populated from the release's `moscow.md` and `story-map.md`:

| Epic | Must Have Story (ID) | Ideate Acceptance Criteria Ref | UAT Scenario(s) Required |
|---|---|---|---|
| Data Source Connection | US-001 Connect Google Drive via OAuth | `AC-US-001` | UAT-001 |
| Sensitivity Classification | US-005 Trigger initial scan and classify files by sensitivity level | `AC-US-005` | UAT-002, UAT-003 |
| Compliance Reporting | US-009 View compliance gap report | `AC-US-009` | UAT-004 |

Should Have and Could Have stories are validated implicitly if a design partner exercises them during the beta window (`beta-program-design`), but they do not require a dedicated UAT scenario or block sign-off — see `acceptance-sign-off`.

---

## Participant Roles

UAT is a facilitated activity with named, non-overlapping roles. No role executes and signs off — the executor and the signer are never the same person, which is what makes sign-off meaningful rather than self-certifying.

| Role | Who | Responsibility |
|---|---|---|
| **Executor** | A design partner from the stakeholder register's design-partner cohort (`stakeholder-mapping`), acting as their real persona | Runs each UAT scenario **and each exploratory session** in the live/live-like environment, records pass/fail and observations |
| **Internal proxy executor** | An internal stand-in (e.g., Shafi acting as Maya Chen) | Used **only** when no design partner is available yet for this release slice — never a permanent substitute; every UAT plan states whether it used a design partner or a proxy, and a proxy-only sign-off is downgraded to conditional (see `acceptance-sign-off`) |
| **Facilitator** | requirements-analyst | Prepares scenarios (`uat-scenario`) **and drafts exploratory charters**, briefs executors, observes without leading (see anti-leading-question guidance in `feedback-template`), captures defects and feedback, compiles results |
| **Sign-off authority** | Shafi + a customer/design-partner representative | Reviews the compiled results against exit criteria and issues the `acceptance-sign-off` decision — two-party, never unilateral |

---

## Environment

UAT runs against a **canary tenant** (`canary-deployment`) or a dedicated **staging** environment (`environment-config`) — never a local development environment. The reason is structural, not procedural: UAT's entire value is that it observes the same chart, same image digest, and same configuration class the rest of the fleet will run. A local dev environment fails Environment Parity by definition, so anything validated there proves nothing about what ships. Exploratory sessions run in the **same** environment as scripted scenarios — a different, less-representative environment would undermine exploration's value the same way it would a scripted scenario's.

| Environment choice | When to use |
|---|---|
| Canary tenant | Design partner is a live, contracted tenant already on the canary wave — UAT runs in their actual namespace against their actual data, the strongest possible signal |
| Staging | No design partner tenant is provisioned yet for this slice, or the scenario requires data conditions (volume, edge-case content) staging can be seeded with more safely than a live customer's environment |

Either way, the environment record for the UAT run (chart version, image digest, tenant id or staging label, feature-flag state per `feature-flag-design`) is captured in the UAT Plan's Environment section — this is what lets a failed scenario be reproduced exactly.

---

## Entry Criteria

UAT does not start until all of the following are true:

- [ ] All Quality-phase gates have passed for this release slice (automated suite green, NFRs verified)
- [ ] The release is deployed to the UAT environment via `canary-deployment` (or `environment-config` staging) — same digest that will eventually reach the full fleet
- [ ] The relevant `feature-flag-design` release flag is configured `true` for the UAT cohort's tenant(s) only
- [ ] Every Must Have story in scope has a corresponding `uat-scenario` written and traced to its Ideate `acceptance-criteria`
- [ ] At least one exploratory charter is drafted per area of meaningful risk or complexity in scope (not every Must Have story needs one — see Exploratory Testing Component below)
- [ ] Executors are briefed and scheduled

If any entry criterion is unmet, UAT does not begin — starting early produces results that cannot be trusted, because the thing being tested is not yet the thing that will ship.

---

## Exit Criteria

UAT closes (moves to `acceptance-sign-off`) when:

- [ ] Every UAT scenario in scope has a recorded pass/fail result
- [ ] Pass rate meets or exceeds the threshold stated in the plan (default: 100% of Must Have scenarios pass; see the plan's stated threshold if lowered with rationale)
- [ ] Zero open Critical or High severity defects (per `feedback-template`'s severity classification) remain unresolved
- [ ] All feedback has been triaged (`feedback-template`) — no unreviewed reports sitting in the queue
- [ ] Every planned exploratory charter has been run and debriefed — this is a **separate** criterion from the pass-rate threshold, since a charter has no pass/fail, only findings; a phase does not close having planned an exploratory session that never actually ran

Exit criteria being met does not automatically mean full sign-off — it means the plan is ready to move to the `acceptance-sign-off` decision, which may still be conditional. See that skill for the sign-off decision itself.

---

## Schedule and Duration

UAT is time-boxed. An open-ended UAT window loses urgency and blocks the release indefinitely for diminishing signal. A typical structure for a single release slice:

| Day | Activity |
|---|---|
| Day 0 | Entry criteria verified; executors briefed; scenarios distributed; exploratory charters drafted |
| Day 1–3 | Scripted scenario execution **and** exploratory sessions, same executor(s), same environment; facilitator observes and logs defects/feedback live |
| Day 4 | Facilitator compiles results; triage pass on all captured feedback (`feedback-template`), scripted and exploratory alike |
| Day 5 | Sign-off meeting — Shafi + customer representative review against exit criteria (`acceptance-sign-off`) |

Exploratory sessions run **alongside** scripted execution, not as a separate phase — they share the same time-box (Day 1–3), the same executor, and the same environment. For a design-partner cohort of 3 companies validating a small Must Have slice, 5 business days is typically sufficient. Larger slices or a design-partner cohort with limited availability may extend the execution window (Day 1–3 → Day 1–7) but the compile-and-decide tail (facilitator compile, triage, sign-off) should not stretch — a slow decision after data is in hand is a process failure, not a testing one.

---

## Exploratory Testing Component

Scripted `uat-scenario`s prove a known example works; they cannot find what no one anticipated. Per Elisabeth Hendrickson's *Explore It!*, this plan includes one or more **time-boxed exploratory sessions**, distinct from (never a replacement for) the scripted Must Have checklist.

Each session is scoped by a **charter**: *"Explore [target/area], with [resources], to discover [information]."* A charter names what to explore and what you're trying to learn, without prescribing exact steps — preserving the freedom to follow what's found. Sessions are time-boxed (typically 45–90 minutes), produce a running log captured live, and end with a debrief (findings, and any new charters the session itself surfaced).

A short heuristics checklist for generating test ideas within a charter: **CRUD** (create/read/update/delete and their interactions), **Boundaries** (min/max/zero/off-by-one), **Position/Goldilocks** (first/last/none/many), **Interruptions** (stop mid-workflow and resume — a high-yield heuristic for state-management bugs scripted tests rarely cover), **Configuration variance** (browser/device/locale/permission/flag differences), and the **Saboteur mindset** (deliberately trying to break things a well-behaved user never would).

**Honesty about who explores**: the requirements-analyst (facilitator) drafts the charter; a human executor (design partner or Shafi-as-proxy) actually explores. An agent reasoning over a UI without a live human driving is not exploratory testing under this definition — it's scripted testing wearing an exploratory label. State this plainly rather than gloss over it.

Full session-record template, the SFDIPOT coverage audit, and charter-generates-charter discipline: `references/exploratory-session-template.md`.

---

## Worked Example

Full UAT plan for Release 1, including two exploratory sessions filled in: `references/worked-example.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Scope traces to Musts | Every UAT scenario maps to a Must Have story and its AC | UAT scenarios invented ad hoc, untraceable to the backlog |
| Live/live-like environment | Canary tenant or staging, digest and flags recorded | "Local dev" or an environment not on the promotion path |
| Roles separated | Executor, facilitator, and sign-off authority are distinct people | The same person executes and signs off |
| Entry criteria enforced | UAT does not begin until Quality gates and deployment are confirmed | UAT starting against an unverified or pre-Quality-gate build |
| Time-boxed | A stated schedule with a compile-and-decide tail that does not drift | Open-ended UAT window with no decision date |
| Exit criteria explicit | Pass-rate threshold and defect bar stated before execution begins | Vague "looks good" closure with no stated bar |
| Exploratory sessions run | At least one charter drafted and debriefed per area of meaningful risk | Zero exploratory sessions, or a charter drafted but never run |
| Exploration stays human-driven | Charter drafted by the agent, explored by a human executor | An agent's own reasoning over the UI presented as "exploratory testing" |

---

## Anti-Patterns

**UAT as a second QA pass.** Re-running the same automated-test scope with humans clicking instead of asserting duplicates the Quality phase and produces no new signal. UAT scenarios validate real-world behavior and human judgment calls (is this report actually useful to Maya?) that automated assertions cannot. **This is not an argument against exploratory sessions** — exploration is the complementary activity that finds what scripted scenarios structurally can't, not a second scripted pass under a different name.

**UAT in a non-production-like environment.** Running scenarios against a developer's local instance of the app proves nothing about what the canary tenant or the fleet will experience — it violates Environment Parity by definition and its results cannot be trusted for a widen-rollout decision. The same applies to exploratory sessions.

**Unbounded scope.** Testing every Should Have and Could Have "while we're at it" dilutes facilitator and executor time and delays the sign-off decision without improving the Must Have signal the release actually depends on.

**No entry criteria check.** Starting UAT before Quality gates pass means defects found during UAT could have been caught cheaper, earlier, by automation — and any UAT pass recorded against a not-yet-final build is not evidence about the build that will actually ship.

**Executor and signer are the same person.** Self-certification defeats the purpose of a two-party sign-off; see `acceptance-sign-off`.

**A charter drafted but never run.** Listing exploratory charters in the plan without a session record, notes, and a debrief is the exploratory equivalent of a UAT scenario with no recorded result — the exit criterion requires charters run and debriefed, not merely proposed.

**An agent "exploring" without a human.** Simulating exploratory testing by having an agent reason over screenshots or a UI description, with no live human actually driving the session, produces a scripted-testing artifact mislabeled as exploratory — the value Hendrickson's technique provides comes specifically from in-the-moment human judgment.

---

## Output Format

Full fill-in template, including the exploratory-session fields: `references/output-format-template.md`.
