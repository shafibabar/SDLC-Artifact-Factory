# Mission Statement — Template, Expanded Checklist, and Worked Examples

Self-contained reference for the `mission-statement` skill. The body carries the
vision-vs-mission distinction, the quality criteria in brief, the anchoring role,
and the anti-patterns. This file carries the copyable artifact template, the
expanded quality checklist with its diagnostic tests, and four fully worked
examples — three strong/weak contrasts plus one worked mission for this repo's
data-estate / compliance platform, each with the reasoning that produced it.

---

## 1. The artifact template

Copy this as the starting shape for a produced mission-statement artifact. It
follows the plugin's artifact frontmatter standard (`name`, `version`, `phase`,
`owner`, `created`) plus a `product` field naming the product it belongs to.

```markdown
---
name: mission-statement
product: [product name]
version: 1.0.0
phase: strategy
created: [YYYY-MM-DD]
owner: product-strategist
---

# Mission Statement

[The mission — 1–3 sentences, <= 50 words, present tense]

## Scope Boundary

**In scope:** [3–5 activities the mission explicitly includes]
**Out of scope:** [3–5 activities the mission explicitly excludes]

## Vision Alignment

[One sentence: how executing this mission over time produces the vision]

## Translation Note

[Per Lemay's connective-role framing: what ambiguous input this mission
translates — Shafi's problem statement, the vision — into a scope-constraining
statement the downstream okr-authoring and gtm-strategy work can act on.]
```

The **Scope Boundary** section is what makes a mission operational rather than
decorative. A mission you cannot derive an out-of-scope list from is too vague to
constrain anything — this is the single most common failure and the reason the
template forces the list to be written down.

The **Translation Note** is optional but recommended: Lemay (*Product Management
in Practice*) frames the PM's core output as translation — turning ambiguous
intent into a form the next function can act on without re-clarification. Naming
that translation makes the mission's job explicit rather than implicit.

---

## 2. The mission sentence formats

Two equivalent shapes; pick whichever reads more naturally for the product.

**Format A — "so that" (outcome-forcing):**

```
We [verb: what we do] for [target user] so that [outcome the user experiences].
```

The connecting phrase `so that` is load-bearing: it forces the sentence to end on
the *beneficiary's* outcome, not on the product's activity. If you can delete
everything after `so that` and the sentence still feels complete, the mission is
describing an output, not an outcome.

**Format B — action-first, one sentence:**

```
[Company/product] [verb]s [what] for [target user], [outcome clause].
```

Both cap at 50 words. Both must contain exactly one primary action verb (see the
single-verb test below).

---

## 3. Expanded quality checklist

Each criterion below has a **diagnostic test** — a concrete thing to do to the
sentence to decide pass or fail, rather than a subjective judgement.

| # | Criterion | Diagnostic test | Pass | Fail |
|---|---|---|---|---|
| 1 | **Present tense** | Read it aloud with "right now, today" prepended. | Still true and sensible today. | Only becomes true in the future — it's a vision. |
| 2 | **Single-verb test** | Count the primary action verbs. A mission names one primary action, not a menu. | Exactly one primary action verb. | A list of verbs (`scans, classifies, reports, alerts, dashboards`) — that's a feature list. |
| 3 | **Active, specific verb** | Check the verb against the weak-verb blocklist: `enable, help, provide, support, empower, facilitate, leverage`. | A concrete verb: `maps, classifies, catalogs, monitors, reconciles`. | A weak verb as the primary action. |
| 4 | **Named beneficiary** | Could a competitor in a totally different market use this exact beneficiary word? | A specific group (`compliance teams at regulated SMBs`). | A generic word (`users`, `companies`, `people`, `organizations`). |
| 5 | **Stated outcome** | Apply the "so that they can…" reversal — finish the sentence from the user's side. | Names what the user can now *do* or *know*. | Names only what the product outputs. |
| 6 | **Scope constraint** | Try to write the out-of-scope list. | You can name 3–5 things the mission excludes. | Any feature could be justified — nothing is excluded. |
| 7 | **Vision alignment** | Ask: "If we nailed this mission at scale for years, would the vision be true?" | Yes — the mission is the vision's execution path. | The mission could fully succeed while the vision stayed unmet. |
| 8 | **Length** | Word count. | 1–3 sentences, <= 50 words. | Over 50 words, or many disconnected clauses. |

The single-verb test (row 2) is the cheapest way to catch the most common failure
— a "mission" that is really a capability inventory. If the sentence needs commas
to separate multiple verbs, it has stopped being a mission and become a roadmap.

---

## 4. Worked examples — strong vs weak

### Example 1 — the feature-list trap

**Weak:**
> "Our mission is to provide scanning, classification, reporting, dashboards, and
> alerts for enterprise data."

- Fails **single-verb** (five verbs) and **stated-outcome** (no beneficiary
  outcome — only capabilities).
- Fails **scope constraint**: you cannot derive an out-of-scope list, because any
  data feature fits under "and more capabilities."

**Strong rewrite:**
> "We catalog and classify every data asset an organization holds so that its
> compliance team can prove what sensitive data they store and where it lives."

- One primary action (`catalog and classify` reads as a single cataloguing act).
- Outcome is the user's: they can *prove* their data holdings.
- Out-of-scope now derivable: data remediation, DLP enforcement, contract review.

### Example 2 — the mission that is secretly a vision

**Weak:**
> "Our mission is to make every organization's data estate fully transparent and
> compliant."

- Fails **present tense**: "make every organization… fully compliant" is an
  aspirational future end-state. Prepend "right now, today" and it's false.
- This sentence is a perfectly good *vision*. Move it there and write a mission
  describing the present-day work toward it.

**Strong rewrite (the mission that serves that vision):**
> "We map where sensitive data lives across a customer's cloud storage so that
> their Compliance Officer can answer an auditor without a manual data hunt."

### Example 3 — the no-constraint mission

**Weak:**
> "Our mission is to help companies manage their data better."

- Fails **active-verb** (`help`), **named-beneficiary** (`companies`),
  **stated-outcome** (`manage… better` is unobservable), and **scope
  constraint** (every data product on Earth qualifies).

**Strong rewrite:**
> "We continuously reconcile a regulated SMB's data inventory against its
> retention policy so that its Data Steward sees policy violations the day they
> occur, not at audit time."

### Example 4 — the internally-focused mission

**Weak:**
> "Our mission is to build the best data-estate platform using cutting-edge AI."

- Fails **stated-outcome** and **named-beneficiary**: it describes internal
  ambition and technology, not user benefit. "Best" and "cutting-edge AI" are
  claims about the builder, not outcomes for the buyer.
- This is also, in Dunford's (*Obviously Awesome*) terms, trend-led positioning —
  "cutting-edge AI" ages into generic category noise the moment the trend cools.

**Strong rewrite:** any of Examples 1–3's strong versions; each states a user
outcome and names no internal technology.

---

## 5. Worked mission for this repo's data-estate / compliance platform

Context (from `sdlc-context.json`'s `first_product` and the repo personas): an
event-driven microservices platform that maps and classifies an organization's
data estate across Google Drive, S3, and uploaded PDF/DOCX/XLSX files, with
per-tenant physical isolation, targeting SOC 2 readiness for regulated SMBs. The
two named beneficiary personas are the **Data Steward** and the **Compliance
Officer**.

**Vision (for reference — future-tense, not the mission):**
> "A world where any regulated organization can answer 'what sensitive data do we
> hold, and where?' in seconds, with total confidence and zero data movement."

**Derivation walk-through:**

1. **Primary action.** The core present-day act is building and maintaining an
   inventory of data assets and their sensitivity. Candidate verbs: `map`,
   `catalog`, `classify`, `discover`. Chosen: **catalogs and classifies** —
   `catalog` names the inventory-building act; `classify` names the sensitivity
   labelling that makes the inventory useful. This reads as a single cataloguing
   discipline, so it passes the single-verb test.
2. **Beneficiary.** From the vision's target user, narrowed to the primary
   present-day persona: the **Compliance Officer** (with the **Data Steward** as
   the daily operator). Specific, not "companies."
3. **Outcome.** Applying the "so that they can…" reversal: they can *demonstrate*
   exactly what sensitive data the organization holds and where it lives — the
   auditor-facing job that is the whole point.
4. **Scope constraint.** Naming the outcome makes the out-of-scope list fall out:
   the mission covers discovery and classification, not remediation, not access
   enforcement, not moving or deleting data.
5. **Data-movement constraint.** The repo's per-tenant physical isolation is a
   non-negotiable differentiator, so the mission states it: the work happens
   without the customer's data leaving their own infrastructure.

**Worked mission statement:**

```markdown
---
name: mission-statement
product: data-estate-compliance-platform
version: 1.0.0
phase: strategy
created: 2026-07-31
owner: product-strategist
---

# Mission Statement

We catalog and classify every data asset an organization holds across its cloud
storage and uploaded documents, for the Compliance Officer and Data Steward of a
regulated SMB, so that they can demonstrate exactly what sensitive data they hold
and where it lives — without their data ever leaving their own infrastructure.

## Scope Boundary

**In scope:** connector-based discovery across Google Drive and S3; parsing and
classifying uploaded PDF/DOCX/XLSX files; maintaining a per-tenant sensitivity
inventory; surfacing where each sensitive asset lives.
**Out of scope:** deleting, moving, or remediating data; access-control
enforcement / DLP blocking; contract or policy authoring; any workflow that
requires copying customer data out of the tenant's isolated environment.

## Vision Alignment

Executed continuously at scale, a complete and current sensitivity inventory per
tenant is exactly the substrate that lets any regulated organization answer "what
sensitive data do we hold, and where?" in seconds — the vision's end state.

## Translation Note

This mission translates Shafi's problem statement and the vision into a scope
constraint the okr-authoring and gtm-strategy work consume: OKR Key Results must
move coverage/accuracy of the inventory (the mission's outcome), and the GTM
positioning statement inherits "catalog and classify, no data movement" as its
category and differentiator.
```

**Why this passes every criterion:**

| Criterion | How it passes |
|---|---|
| Present tense | "We catalog and classify… today" is true now. |
| Single verb | `catalog and classify` = one cataloguing act, not a menu. |
| Active verb | `catalog`, `classify` — no `help`/`enable`/`support`. |
| Named beneficiary | Compliance Officer and Data Steward of a regulated SMB. |
| Stated outcome | They can *demonstrate* their sensitive-data holdings. |
| Scope constraint | Out-of-scope list (remediation, enforcement, data movement) derives directly. |
| Vision alignment | The inventory is the vision's substrate. |
| Length | 46 words, one sentence. |

---

## 6. How the mission feeds downstream artifacts

- **okr-authoring** — the mission's stated outcome is the source of the top-level
  Objective; Key Results must measure movement of that outcome (inventory
  coverage, classification accuracy), never feature delivery. A KR that moves
  something the mission does not name is a signal the mission or the KR is wrong.
- **gtm-strategy positioning statement** — inherits the mission's verb and
  differentiator as its category and "unlike [alternative]" clause. Per Dunford,
  the positioning statement is a *compression* of a fuller positioning exercise;
  the mission supplies its outcome and scope, not its market-category choice.
- **vision-statement** — the mission is checked *against* the vision (criterion 7);
  they are authored as a pair, vision first, mission as its present-day execution
  path.
- **business-model-canvas** — the mission's beneficiary and outcome should match
  the canvas's Customer Segments and Value Propositions blocks; a mismatch means
  one artifact drifted.

---

## 7. Common review findings (fast triage)

When reviewing a submitted mission, check these in order — each is a hard stop:

1. Prepend "today, right now" — if false, it's a vision (Example 2).
2. Count primary verbs — more than one means feature list (Example 1).
3. Scan for `help/enable/provide/support` as the main verb (Example 3).
4. Try to write the out-of-scope list — if you can't, it's too broad (Example 3).
5. Check the beneficiary word survives the competitor test (Example 3).
6. Confirm executing it produces the vision (criterion 7).

Anything that fails goes back with the specific failing criterion named, not a
vague "make it punchier."
