# Epic Decomposition Techniques

Reference material for `epic-definition`. Loaded when an agent is splitting a defined epic into
INVEST-sized user stories. Covers the full splitting toolkit, the one non-negotiable rule (never
split by technical layer), and a complete worked decomposition of a repo epic.

Grounded in Mike Cohn, *User Stories Applied* (splitting patterns, INVEST, SPIDR — Cohn's own
pattern set from Mountain Goat Software), Jeff Patton, *User Story Mapping* (walking skeleton /
release slices), and well-established user-story craftsmanship practice (verb-before-noun,
Richard Lawrence's widely-taught splitting patterns). Product context: a data-estate/compliance
platform whose primary personas are the **Data Steward** and the **Compliance Officer**.

---

## 0. The one rule: split by outcome, never by layer

Every story produced by decomposition must be an **independently valuable, user-facing outcome**
(INVEST — Independent, Negotiable, Valuable, Estimable, Small, Testable). A split into
"frontend story / backend story / database story" violates this: those are **tasks** performed to
build one story, not stories. If a candidate story delivers nothing a persona could observe or use
on its own, it is a task — fold it back inside the story whose outcome it serves.

**INVEST as the acceptance test for a split.** After splitting, each fragment should be:
Independent (no forced ordering with a sibling), Negotiable (a placeholder for a conversation, not a
frozen spec), Valuable (a persona gains something), Estimable, Small (fits a sprint), Testable
(story-level Given/When/Then can be written for it). If a fragment fails Valuable or Small, split
again or merge back.

---

## 1. The splitting toolkit

| Technique | Split when… | Repo example |
|---|---|---|
| **By workflow step** | The epic is a multi-step process | "Review a classified estate" → connect → classify → review → remediate, each a story |
| **By business rule** | Behaviour varies by a rule or threshold | Retention-policy variations: 7-year financial vs 30-day transient, each its own story |
| **By user role** | Different personas use the capability differently | Data Steward *classifies*; Compliance Officer *signs off* — separate stories |
| **By data variation** | Same behaviour, different data source/type | Google Drive vs S3 vs SharePoint connectors, each a story |
| **By interface / CRUD** | One entity bundles create/read/update/delete | Split *view* a classification from *override* a classification |
| **By happy / edge path** | A simple common case is entangled with rare complex ones | Ship the clean-connection path first; expired-credential recovery is a later story |
| **Verb-before-noun** | The epic title bundles multiple actions | "connect, configure, and monitor a source" → split the *verbs* first, before any data split |
| **Defer the hard part** | A performance/robustness concern inflates the story | Ship correct-but-slow classification first; defer the scale/perf story |
| **Spike out** | The story is not yet **Estimable** | Carve a time-boxed research spike, then re-split with what it learned |

**Sequencing tip (craftsmanship practice).** When several techniques apply, **split by verb before
splitting by noun**: decompose a compound-action epic into its constituent verbs *first*, then apply
data-variation or configuration splits within each verb. "Connect, configure, and monitor" becomes
three verb-stories; only then does "connect" fan out into Google-Drive-connect vs S3-connect.

---

## 2. SPIDR — Mike Cohn's five-pattern splitting set

SPIDR (from Mike Cohn / Mountain Goat Software) is a compact mnemonic for five reliable ways to
split a story or epic that is too big:

| Letter | Pattern | Split by… | Repo example |
|---|---|---|---|
| **S** | **Spike** | Carving out a time-boxed investigation when the work isn't estimable | Spike: "how does the SharePoint Graph API paginate?" before the SharePoint connector story |
| **P** | **Paths** | The distinct paths a user can take through the capability | Happy-path connection vs re-authenticate-after-expiry path |
| **I** | **Interfaces** | The different interfaces/clients/data types the work supports | Web UI classification review vs API classification export |
| **D** | **Data** | Narrowing to a subset of the data first | Classify PDF/DOCX first; XLSX and image OCR as later stories |
| **R** | **Rules** | Relaxing a business rule now and adding it back later | Classify ignoring per-tenant retention rules first; apply retention rules in a follow-up |

So SPIDR expands to **Spike, Paths, Interfaces, Data, and Rules**. Prefer these over splitting by
technical component: every SPIDR fragment still delivers an observable slice, whereas a
component split does not.

**SPIDR vs the general toolkit.** SPIDR is a curated subset chosen for reliability; "by workflow
step", "by user role", and "verb-before-noun" from section 1 sit outside SPIDR but compose with it.
Use SPIDR as the default first pass; reach for the wider toolkit when SPIDR's five don't fit.

---

## 3. The walking skeleton and release slices (Patton)

When epics feed a story map, decomposition interacts with slicing. Jeff Patton's **walking
skeleton** (a term he credits to Alistair Cockburn) is the thinnest end-to-end path across the
*entire* backbone that actually works, however ugly — not a polished slice of one activity. The first
story drawn from each epic on the backbone should contribute to that skeleton.

- A **release slice** is a horizontal cut across the map: it must be end-to-end *viable*, not merely
  "all the Must-haves." This is distinct from a MoSCoW priority cut.
- Distinguish a **learning-MVP** (a cheap, possibly throwaway experiment to validate a belief) from
  a **release-MVP** (the shippable walking skeleton). Do not let one masquerade as the other — a
  common failure mode when an "MVP" epic is scoped in Ideate before any code exists.

Decomposition implication: when you split an epic, tag which resulting story belongs to the walking
skeleton (the thin end-to-end first slice) versus which are later-slice enrichments.

---

## 4. Worked decomposition — "A Data Steward reviews a classified estate"

**Epic under decomposition:**

```
EPIC-004: A Data Steward reviews a classified estate

As a result of this epic, the Data Steward will be able to review every classified data source
across the estate, judge each classification, and correct the ones that are wrong — without
exporting to a spreadsheet.

Bounded Context: Classification Review
```

### Step 1 — pick the primary lens

The epic is a **multi-step workflow** (view → inspect → judge → correct → confirm), so **split by
workflow step** first. This yields the narrative spine.

### Step 2 — first-pass stories (by workflow step)

| Story | Outcome | Walking skeleton? |
|---|---|---|
| US-001 | Data Steward sees every classified source on one screen, grouped by sensitivity | Yes — thin end-to-end view |
| US-002 | Data Steward opens a source and inspects the files and the classification assigned to each | Yes |
| US-003 | Data Steward overrides an incorrect file classification | Yes |
| US-004 | Data Steward confirms a classification as correct (accepts the machine's call) | No — later slice |
| US-005 | Data Steward filters the estate view by source, sensitivity, or last-classified date | No — later slice |

### Step 3 — second-pass refinements (apply finer patterns where a story is still too big)

- **US-001** is still large → apply **SPIDR-Data**: ship the estate view for **PDF/DOCX** sources
  first (US-001a), add **XLSX and image/OCR** sources later (US-001b).
- **US-003** (override) bundles two rules → apply **by business rule**: overriding *up* to a higher
  sensitivity (US-003a) vs overriding *down* to a lower one — the latter needs a Compliance Officer
  co-sign (US-003b, and note the **by user role** boundary it exposes).
- The re-authentication of an expired source is a distinct **path** → **SPIDR-Paths** carves it into
  its own story rather than complicating US-002's happy path.

### Step 4 — what we deliberately did NOT do

- We did **not** create "US: build the estate REST endpoint" or "US: add the classifications table."
  Those are **tasks** inside US-001/US-002, not stories — splitting by layer is the rule violation.
- We did **not** write story-level Given/When/Then here. Each story gets its detailed acceptance
  criteria from `acceptance-criteria` *after* this decomposition, per the epic-vs-story altitude rule.

### Resulting decomposition (titles only, back on the epic)

```
Decomposition:
- US-001a: See the classified estate (PDF/DOCX sources) on one screen
- US-001b: Extend the estate view to XLSX and image/OCR sources
- US-002:  Inspect a source's files and their assigned classifications
- US-003a: Override a file classification upward (raise sensitivity)
- US-003b: Override downward with Compliance Officer co-sign
- US-004:  Confirm a machine classification as correct
- US-005:  Filter the estate view by source / sensitivity / date
```

Seven stories, each an independently valuable Data-Steward outcome, from one epic — a healthy 3–10
band, split by outcome and workflow (never by layer), with the walking-skeleton subset (US-001a,
US-002, US-003a) identifiable for the first release slice.
