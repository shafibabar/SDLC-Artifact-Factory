# Hypothesis, Four-Risk Line and Epic Acceptance Criteria

Self-contained reference for `epic-definition`. Read it before writing an epic's first hypothesis, whenever one of the four risks has no evidence, and whenever epic acceptance criteria start to read like test steps.

Grounded in Marty Cagan, *Inspired* (outcome over output, the four big risks); Mike Cohn, *User Stories Applied* (the Three Cs, "don't write novels"); and Ken Pugh, *Lean-Agile Acceptance Test-Driven Development* (concrete examples before rules; not ready without one).

---

## 1. The hypothesis

**Shape:** *If we deliver [this epic's outcome], we believe [actor] will [behaviour change], shown by [signal], which moves [KR-n.m].*

Where each part comes from:

| Part | Source |
|---|---|
| Actor and behaviour change | The impact on the impact map's selected path that this epic's deliverable is meant to cause. At lean, the trace line's behaviour change. With no map at standard, the KR's metric read as a behaviour |
| Signal | The impact's signal on the map ("we would see it in ___"). Copy it, do not invent a second one |
| KR | The map's goal, or the KR directly |

**It must be able to fail while the epic succeeds.** An epic *succeeds* when it ships and its epic criteria are met. Its hypothesis *succeeds* only when the actor's behaviour changes. Keeping the two apart is the point: if the front desk can now see who is still coming (epic met) but patients do not reply to confirm requests (hypothesis failed), the bottleneck is elsewhere, and the impact map's re-plan trigger says to try the next option on the same impact, not to "improve" this epic.

| Weak | Why | Better |
|---|---|---|
| "Patients will use the confirm feature" | Feature use restated as a belief; it cannot fail in a useful way (the impact-mapping anti-pattern "feature usage as impact") | "Patients booked 14+ days ahead reply to a confirm request instead of silently not turning up, shown by reply rate per request, moving KR-2.1" |
| "This will improve the onboarding experience" | No actor, no signal, no KR | "Applicants submit with every document attached, shown by first-submission validity rate, moving KR-1.2" |
| "Councils will be happy" | Unfalsifiable | "Validation officers stop re-checking items the report already passed, shown by manual re-checks per application" |

Cagan's reason (*Inspired*): a team measured on output ships and moves nothing (the *feature factory*). The hypothesis keeps the epic measured on the outcome it was chosen for.

---

## 2. The four-risk line

Cagan names four risks every idea must face **before** significant delivery effort: **value** (will they choose to use it), **usability** (can they work out how), **feasibility** (can it be built with what we have) and **viability** (does it work for the business: legal, finance, support, sales). An epic about to be decomposed into stories is exactly that moment, so each epic carries one line per risk.

Each risk gets one of three statuses:

| Status | Write | When |
|---|---|---|
| **tested** | The evidence: an assumption test result (T-n), an interview snapshot, a design-partner result | Something was observed, not just believed |
| **assumed** | The belief, plus the test that would settle it and when | Nothing observed yet; most risks are here in Ideate |
| **low** | The reason | The risk genuinely does not apply ("viability: low, internal tool, no revenue or legal exposure") |

Where the evidence lives:

| Risk | Look in |
|---|---|
| Value | The opportunity solution tree's assumption tests; desirability assumptions typed on the impact map |
| Usability | Usability assumptions on the map; interview snapshots |
| Feasibility | The NFR specification's architecture hand-off; feasibility assumptions on the map; an integration spike |
| Viability | Viability assumptions on the map; business rules and constraints in the FRD (regulatory, contractual) |

Rules:

- **No blank risk.** A blank hides an untested risk entering delivery, which Cagan calls unvalidated however good the specification.
- **"Assumed" is allowed, unexplained is not.** In Ideate most risks are assumed. Each names its test (a T-n on the tree, a spike story, a question for the user) so the gap is visible.
- **The agent does not invent evidence.** A risk is "tested" only when an artifact or the user records the result.
- **Feasibility assumed and High on the architecture hand-off** is a reason to put a spike title in the decomposition (size "+spike").
- At lean, the trace line's typed assumption covers the riskiest of the four; the full line is optional.

Example line:

> **Risks:** value — tested (T-3: 7 of 10 design-partner practices kept using the concierge version for four weeks) · usability — assumed (staff find the weekly summary without training; checked in the first week's walkthroughs) · feasibility — low (uses the existing calendar export, CON-1) · viability — assumed (practices accept the per-message cost; the user asks two practice owners)

---

## 3. Epic acceptance criteria

Two altitudes, kept strictly apart:

| | Epic acceptance criteria | Story acceptance criteria |
|---|---|---|
| Form | 3–5 plain conditions, each with **one concrete example** | Given/When/Then scenarios |
| Answers | "Is the whole outcome delivered?" | "Does this behaviour work, including its edges?" |
| Written | Now, on the epic | Per story, after its example map (`example-mapping`, `acceptance-criteria`) |

**Why high level (Cohn).** A story is Card, Conversation and Confirmation (Cohn, after Ron Jeffries). The card defers detail on purpose so it can be settled in the conversation. Writing Given/When/Then at epic time freezes guesses before that conversation, Cohn's "don't write novels" failure.

**Why an example anyway (Pugh).** Pugh's point is that work is not ready until it has at least one concrete example: an abstract condition nobody has tried against real data is where misunderstandings hide. So each epic criterion carries one real-feeling example (names, numbers, a case), not a scenario.

| | Example |
|---|---|
| **Good** | "The front desk can see, before the 48-hour cut-off, which long-gap patients have not confirmed. *Example: of 10 confirm requests sent for Thursday, 4 are unanswered on Tuesday morning; the list shows those 4 with patient and slot.*" |
| **Too detailed (story level)** | "Given an appointment booked 15 days ahead, When 72 h before start, Then an SMS is queued with text 'Reply C to confirm…'" |
| **Too abstract (no example)** | "The confirmation process works well for all patients." |

Further rules:

- **3–5 criteria.** Fewer than 3 usually means the epic is a story; more than 5 means story detail is leaking in or the epic holds two outcomes.
- **Outcome conditions, not features.** "A Google Drive can be connected without leaving the product", not "an OAuth button exists".
- **No performance or availability numbers.** Those are NFR targets owned by `nfr-specification`; cite the NFR ID if the epic depends on one.
- **Business rules are cited, not restated.** "…respecting BR-4" rather than re-writing the retention rule.
- The example map and the story criteria later refine these; they do not contradict them. If they must, the epic criterion changes through the user, not silently.
