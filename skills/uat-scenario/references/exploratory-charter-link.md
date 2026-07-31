# Pairing a Scripted UAT Scenario Set with an Exploratory Charter

Reference material for the `uat-scenario` skill. The SKILL.md body establishes *that* a scripted scenario set is complemented by a time-boxed exploratory charter, and *why* (scripted checks are structurally incapable of finding what nobody specified). This file holds the concrete charter format, the heuristics, the session shape, the human-executor caveat, and how findings route back into the pipeline — grounded in Hendrickson's *Explore It!* and Crispin & Gregory's *Agile Testing*, applied to the data-estate / compliance platform.

---

## Why a charter, not another scenario

A UAT scenario is a **check**: it confirms a rule someone already wrote down, with a pass/fail result. Automation and scripted UAT both live in this "checking" mode. But a release also needs **testing** in the investigative sense — exploring the deployed system with human judgment to discover what no one thought to specify (Crispin & Gregory's *checking vs. testing* distinction, building on Bach/Bolton).

In the Agile Testing Quadrants (Brian Marick's model, developed at length by Crispin & Gregory), this is **Q3 — business-facing and critiquing the product**: exploratory testing, usability probing, showcases. A team heavy on automated Q1/Q4 checks and scripted Q3 scenarios can still ship something technically correct that is wrong or confusing for a real Data Steward or Compliance Officer. The exploratory charter is what fills Q3's investigative half — and it produces *findings*, not a pass/fail, because a charter has no predetermined expected result to assert against.

---

## The charter format (Hendrickson)

Hendrickson's *Explore It!* gives a single, reusable charter template — a structured mission statement for a session, deliberately narrow enough to focus and open enough to allow discovery:

```
Explore [target / area]
  with [resources]
  to discover [information about risk / quality].
```

- **Explore [target]** names *what* to explore — a feature, a workflow, a component (not the exact steps, which is what preserves the explorer's freedom to follow what they find).
- **with [resources]** names *what to bring* — test data, tools, environment access, personas.
- **to discover [information]** names *what you are trying to learn* — the risk, unknown, or quality concern that justifies the session.

A worked charter for this platform:

> **Explore** the sensitivity-classification workflow, **with** a mix of scanned low-quality PDFs, password-protected files, and edge-case file types in tenant-northwind-uat, **to discover** whether misclassification, silent failures, or crashes occur outside the happy-path documents already covered by scripted UAT scenarios.

Contrast with a scripted scenario: the scenario says "open Q3_Payroll.xlsx, confirm it shows Restricted." The charter says "go find the classification behaviors nobody wrote a scenario for."

---

## Heuristics — how an executor generates test ideas

The charter states the mission; the heuristics give the executor concrete angles of attack when they do not know where to start. Each is a one-line trigger for a class of test idea (Hendrickson):

- **CRUD** — for any persistent thing (a DataAsset, a report, a classification), test Create, Read, Update, Delete, and critically the *interactions* between them (can you delete an asset that a report references? does a re-classification survive a re-scan?).
- **Boundaries** — the edges of any range: minimum, maximum, zero, one, empty, off-by-one — e.g. a tenant with zero scanned assets, or a report covering exactly one Restricted asset.
- **Position / "Goldilocks"** — first, last, only-one, none, many; too few, too many, just right — the first asset in a list vs. the ten-thousandth.
- **Interruptions** — start a workflow, then stop mid-way (navigate away, lose connectivity, let a session expire, switch users) and resume or abandon it. **This is the highest-yield heuristic for finding state-management bugs**, because scripted tests run a workflow start-to-finish and structurally never exercise a half-completed state — e.g. begin marking a report Audit-Ready, then close the tab before confirming, and check whether the report is left in a corrupt half-reviewed state.
- **Configuration variance** — the same feature under different browsers, devices, locales, permission levels, or feature-flag states — a Compliance Officer's view vs. a Data Steward's view of the same asset.
- **Saboteur mindset** — deliberately trying to break things a well-behaved user never would (wrong input types, out-of-order steps, malformed uploads).

Before closing a pass, an executor can run the **SFDIPOT** coverage-category audit (Structure, Function, Data, Interfaces, Platform, Operations, Time — originally James Bach, applied by Hendrickson) to spot blind spots: "have we only ever explored the happy-path UI, never the underlying data, platform, or timing dimensions?"

---

## Session shape — charter, time-box, debrief

Exploratory work is session-based (Hendrickson's lightweight cousin of Bach/Bach Session-Based Test Management — cite the simpler charter/session/debrief loop, not full SBTM's metrics apparatus):

1. **Charter** — the `Explore / with / to discover` mission, drafted before the session.
2. **Time-boxed execution** — typically 45–90 minutes, with **running notes captured live** during the session (actions taken, observations, surprises), not reconstructed afterward from memory.
3. **Debrief** — surface what was learned, what bugs/risks were found, and what *new charters* the session itself suggests (charter-generates-charter: exploration is an ongoing, branching activity).

A lightweight session record: Charter · Time-box · Tester · Environment · Notes (live log) · Bugs/issues found · New charters/questions · Debrief summary.

### A filled-in session record

```markdown
## Exploratory Session — Classification workflow, edge-case documents

**Charter:** Explore the sensitivity-classification workflow, with a mix of scanned
low-quality PDFs, password-protected files, and edge-case file types in
tenant-northwind-uat, to discover whether misclassification, silent failures, or
crashes occur outside the happy-path documents already covered by scripted UAT.

**Time-box:** 60 min · **Tester:** design partner (Maya, Compliance Officer)
**Environment:** tenant-northwind-uat

**Notes (live log):**
- Uploaded a password-protected PDF → scan status stuck on "Scanning" for >5 min,
  no error surfaced to the user. (Interruptions / Saboteur)
- Uploaded a 0-byte .xlsx → classified as "Unclassified," no PII scan attempted;
  unclear to the user whether that is correct or a silent skip. (Boundaries)
- Re-classified an asset to Restricted, then re-ran the scan → sensitivity reverted
  to the auto-detected value, silently discarding the manual override. (CRUD interaction)

**Bugs / issues found:**
- Password-protected file leaves scan in a non-terminating state with no user feedback.
- Manual classification override is silently lost on re-scan.

**New charters / questions:**
- Explore the re-scan pipeline, with assets carrying manual overrides, to discover
  whether any manual metadata survives a re-scan.

**Debrief:** Two findings logged to feedback-template (one High, one Medium). The
override-loss finding was seen last release too — flag as a candidate risk-register entry.
```

Notice the value: none of these findings corresponds to a written acceptance criterion. A scripted scenario set would have passed 100% and still shipped the silent override-loss bug.

### Touring — varying the angle of attack

Hendrickson also describes *touring* a product: exploring the same feature from different vantage points — a brand-new user's perspective, a power user's, a "what is the most valuable data here" perspective — because each vantage surfaces a different class of problem than a single straight-through pass. For this platform, touring the Assets view as a first-time Data Steward (is the sensitivity language even legible?) finds different issues than touring it as a Compliance Officer hunting for the single riskiest Restricted asset. (Whittaker's *Exploratory Software Testing* develops a fuller enumerated named-tour catalog; cite Hendrickson for the charter-driven, angle-varying habit itself.)

---

## Where findings go

A charter has no pass/fail, so its output cannot flow through the scripted result column. Instead:

- **Each finding opens a `feedback-template` record** with an assigned severity — exactly the same pipeline a scripted `Fail` uses, feeding the `acceptance-sign-off` decision. Because a charter has no pass/fail, `uat-plan`'s exit criteria gate on "exploratory charters run and debriefed" *separately* from "100% of Must Have scenarios pass."
- **A recurring finding becomes a `risk-register` entry.** If the same class of problem ("the classification UI silently loses unsaved state on session interruption") surfaces in one release's exploratory pass and again in a later release's, that repetition is itself evidence of a standing exposure worth logging as a risk — not just re-reported as a fresh one-time defect each cycle.

A finding discovered *outside* a scripted scenario's Context is always logged this way — never folded into a `UAT-NNN` scenario result, so the scenario's one-to-one traceability to its source acceptance criterion stays clean.

---

## Release-level quadrant self-audit

Before a release closes Customer Validation, run the quadrant self-audit (Crispin & Gregory): confirm all four quadrants have real coverage, not just automated Q1/Q4 with a scripted Q3 scenario set standing in for genuine investigation.

| Quadrant | Coverage for a data-estate release | Owner |
|---|---|---|
| Q1 — tech-facing, supporting | Unit / component tests (godog step defs, Go units) | test-strategist |
| Q2 — business-facing, supporting | BDD feature files derived from acceptance criteria | test-strategist |
| Q3 — business-facing, critiquing | **Scripted UAT scenarios + exploratory charters** | requirements-analyst |
| Q4 — tech-facing, critiquing | Performance, load, security, chaos | test-strategist |

The failure mode this audit catches: a release with green Q1/Q4 automation and a full scripted Q3 scenario set that nonetheless ran **zero exploratory charters** — so it was thoroughly *checked* and never *tested*. The scripted set alone leaves Q3 half-empty. Make "exploratory charters run and debriefed" a named line in the Definition of Done, distinct from the Must Have scenario pass-rate, so a phase cannot close having explored nothing.

---

## The human-executor caveat — honest about what an agent can and cannot do

Hendrickson is explicit that the value of exploration comes from a **skilled human's in-the-moment judgment** — the same-moment loop of "learn something, immediately design the next probe based on what you just learned." That loop is precisely the part hardest to hand to an agent running a fixed prompt.

So the division of labor for this repo is:

- **An agent (the `requirements-analyst` acting as facilitator) authors the charter and the heuristics checklist.** This is a concrete artifact an agent *can* produce well — a focused mission plus the angles of attack to try.
- **A human executor does the actual exploring** — a design partner, or Shafi as internal proxy, using the charter as a mission brief and their own curiosity to follow what they find.

An agent attempting to "explore" a UI autonomously (clicking through screenshots) would be simulating scripted testing under an exploratory label — not doing what the book describes. State the split plainly rather than pretend equivalence. This does not introduce a *new* scarce-human-bandwidth constraint: the existing UAT model already depends on a design partner or Shafi-proxy per `uat-plan`; the charter simply makes that dependency visible, because a genuine exploratory session cannot be scripted away the way a scenario execution nominally could be handed to a proxy following steps.

---

## Summary — two artifacts, one release

| | Scripted UAT scenario set | Exploratory charter |
|---|---|---|
| Answers | "Do the agreed Must Have rules work?" | "What did nobody think to specify?" |
| Shape | Given/When/Then, pass/fail | `Explore / with / to discover`, findings only |
| Derived from | A specific `acceptance-criteria` ID | A risk or quality concern |
| Quadrant | Q3, confirmatory (checking) | Q3, investigative (testing) |
| Authored by | requirements-analyst (from the AC) | requirements-analyst (as facilitator) |
| Executed by | A human following the steps | A skilled human following curiosity |
| Output routes to | `feedback-template` on `Fail` | `feedback-template` per finding; `risk-register` if recurring |

Both run in the same environment, in the same schedule window, assigned to the same executor — authorized and scheduled by `uat-plan`. Neither substitutes for the other.
