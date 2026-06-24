---
name: example-mapping
description: >
  Teaches how to run Example Mapping — a structured conversation technique (Matt
  Wynne) for exploring a user story, discovering its rules, surfacing examples
  that clarify those rules, and identifying questions that must be answered before
  the story is ready. Example Mapping bridges acceptance criteria and BDD feature
  files by making implicit rules explicit through concrete examples. Used by the
  requirements-analyst agent during the Ideate phase after acceptance criteria
  are drafted.
version: 1.0.0
phase: ideate
owner: requirements-analyst
tags: [ideate, example-mapping, bdd, acceptance-criteria, discovery, three-amigos]
---

# Example Mapping

## Purpose

Example Mapping is a structured technique for exploring user stories before they enter a sprint. It surfaces:
- The **rules** the story must comply with
- **Examples** that concretely illustrate each rule (and its exceptions)
- **Questions** that must be answered before the story is ready

An example map makes implicit assumptions explicit. It consistently reveals scope that was invisible in the story and acceptance criteria — catching it here, in discovery, is far cheaper than catching it in implementation or testing.

---

## The Four Card Types

Example Mapping uses four coloured cards (or equivalent notation):

| Card | What it captures |
|---|---|
| **Story (yellow)** | The user story being explored — one per session |
| **Rule (blue)** | A business rule or acceptance criterion that must be true for the story |
| **Example (green)** | A concrete, specific scenario that illustrates a rule (or its exception) |
| **Question (red)** | An open question that must be answered before the story can be accepted |

A finished example map: one yellow card at the top; blue cards in a row beneath it; green cards beneath each blue card (one or more per rule); red cards collected separately.

---

## Structure Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│ STORY (yellow): US-001 — Compliance Officer views gap report     │
└──────────────────────────────────────────────────────────────────┘

┌─────────────────────┐  ┌──────────────────────┐  ┌────────────────────┐
│ RULE (blue):        │  │ RULE (blue):          │  │ RULE (blue):       │
│ Report shows all    │  │ Report prioritises    │  │ Report accessible  │
│ gaps, not just      │  │ gaps by severity      │  │ within 30 min of  │
│ critical ones       │  │ (Critical first)      │  │ initial scan       │
└─────────────────────┘  └──────────────────────┘  └────────────────────┘
│                         │                          │
├─[Example] 100k files    ├─[Example] Mix of         ├─[Example] 100k files
│  with 3 critical,       │  Critical, High, Med     │  scan completes in
│  12 high, 200 low →     │  gaps → Critical          │  28 min → report
│  all 215 shown          │  first in list            │  available at 28m
│                         │                          │
├─[Example] 0 gaps →      ├─[Example] All same       └─[Question] What if
│  empty state shown,     │  severity → alpha         scan takes > 30 min?
│  not error              │  by file name             (waiting for NFR-PERF)
│                         │
└─[Question] Are gaps     └─[Example] No gaps of
  from prior scans         a severity → that
  included or only         section hidden, not
  the latest?              shown as empty

┌──────────────────────────────────────────────────────────────────┐
│ QUESTIONS (red — collected separately):                          │
│ Q1: Are prior-scan gaps included or only latest?                 │
│ Q2: What if the scan takes longer than 30 minutes?               │
└──────────────────────────────────────────────────────────────────┘
```

---

## How to Run Example Mapping

### Participants (Three Amigos model)

In a team context, example mapping is a "Three Amigos" session — product, development, and testing, each contributing their perspective. In solo mode (Han Solo), the requirements-analyst agent plays all three roles explicitly:

- **Product perspective:** What is the user trying to accomplish? What would they expect?
- **Development perspective:** What rules need to be implemented? What edge cases will arise?
- **Test perspective:** What scenarios would expose a bug? What's the simplest example that proves the rule?

### Steps

1. **Place the story card.** Read the story aloud. Confirm the "as a / I want to / so that" is clear.
2. **Surface rules.** For each acceptance criterion, create a blue rule card. Ask: "Are there any implicit rules we haven't written down yet?" Add a blue card for each.
3. **Add examples per rule.** For each rule, ask: "What is the simplest example that proves this rule is satisfied?" Add a green card. Then: "What is a counter-example that would expose a bug?" Add another green card.
4. **Capture questions.** When a disagreement or uncertainty arises about how a rule should work, stop and write a red question card. Do not resolve it through debate — record it and move on.
5. **Assess readiness.** After the map is complete:
   - A story with no red cards is ready for the sprint
   - A story with red cards is not ready — resolve the questions first
   - A story with too many blue cards for one sprint must be split

---

## Reading the Map

| Map state | Interpretation |
|---|---|
| Many rules, few examples | The rules are probably not yet understood in concrete terms — work through examples |
| Many examples per rule | The rule may be too broad — consider splitting |
| Many questions | The story is not ready — do not put it in a sprint |
| No questions | Either the story is well-understood, or the team didn't probe hard enough — check by asking "what could go wrong?" |

---

## From Examples to BDD Scenarios

Once the map is clean (no red cards), each green example card becomes a BDD scenario in the `test-strategist`'s Gherkin feature file. The language of the example card is the starting point for the Given/When/Then language.

**Example card text:** "100k files with 3 critical, 12 high, 200 low → all 215 shown in report"

**Becomes Gherkin:**
```gherkin
Scenario: All gaps shown regardless of severity
  Given the estate has been scanned and contains 3 critical gaps, 12 high gaps, and 200 low gaps
  When the Compliance Officer opens the gap report
  Then all 215 gaps are displayed in the report
  And gaps are visible across all three severity levels
```

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Concrete examples | Every rule has at least one concrete example with specific data | Rules stated as general principles without examples |
| Counter-examples | Every rule has at least one counter-example or negative case | Only positive examples per rule |
| Questions captured | All disagreements and uncertainties captured as questions | Debates resolved by authority with no record |
| Readiness signal | Map is used to decide sprint readiness | Map produced but story pushed into sprint with red cards unresolved |
| BDD linkage | Each green card maps to a named scenario in the feature file | Example maps that don't feed into test artifacts |

---

## Output Format

```markdown
---
artifact: example-map
product: [product name]
story-id: US-[ID]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
ready-for-sprint: [yes / no — if no, list blocking questions]
---

# Example Map: US-[ID] — [Story title]

## Story
As a [Persona], I want to [action], so that [outcome].

## Rules and Examples

### Rule 1: [Rule statement]
| Example (green) | Type |
|---|---|
| [Concrete scenario with specific data] | Happy path |
| [Counter-example or negative case] | Negative |
| [Edge case at system boundary] | Edge |

### Rule 2: [Rule statement]
[Repeat]

## Open Questions (Red)
| ID | Question | Impact | Owner | Target date |
|---|---|---|---|---|

## Sprint Readiness
[Ready / Not ready — if not ready, list the blocking question IDs]

## BDD Scenario Map
| Example | Gherkin Scenario Name |
|---|---|
| [Example card text] | [Scenario title in feature file] |
```
