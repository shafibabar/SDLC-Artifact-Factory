# Epic Format, Acceptance Criteria, and the Work-Item Hierarchy

Reference material for `epic-definition`. Loaded when an agent needs the full epic artifact
template, the rule separating epic-level from story-level acceptance criteria, the complete
theme/epic/story/task hierarchy, or the sizing signals that mark work as epic-scale.

Grounded in Mike Cohn, *User Stories Applied* (epic-as-unsplit-story, INVEST, themes), Jeff Patton,
*User Story Mapping* (backbone tasks, walking skeleton), and this repo's data-estate/compliance
product context (personas: Data Steward, Compliance Officer).

---

## 1. The work-item hierarchy

Four levels, from broadest to narrowest. Only the middle two carry acceptance criteria.

| Level | Definition | Typical sizing | Owns acceptance criteria? | Origin in the literature |
|---|---|---|---|---|
| **Theme** | A loose label grouping related epics for release-level or roadmap reporting | A release, a quarter, or larger | No — reporting only | Cohn uses "theme" as a lightweight grouping above epics |
| **Epic** | One coherent outcome, too large to complete in a single sprint, splitting into 3–10 stories | Several sprints | Yes — 3–5 **high-level** conditions | Cohn: "a story too big to plan into an iteration"; this repo layers a hypothesis + OKR trace on top |
| **Story** | One independently valuable, user-facing outcome that fits in a sprint | Days | Yes — detailed **Given/When/Then** | Cohn/Wake INVEST; format owned by `user-story-writing` |
| **Task** | A technical step performed to build a story (a migration, a handler, a query) | Hours | No — no independent user value | Standard agile decomposition |

**Terminology bridges.**

- In Jeff Patton's story-map vocabulary there is no "epic." The map's **backbone tasks** (the
  top-level narrative-spine activities) are the pre-decomposition equivalent of an epic. When a
  story map already exists, its backbone tasks seed the epic list directly.
- Cohn's book uses "epic" only to mean *a big, unsplit story*. This repo's richer construct
  (hypothesis + OKR linkage + Bounded Context tag) is an intentional Lean-Startup-style adaptation
  for product-discovery rigor — documented as a divergence, never attributed to Cohn.

---

## 2. Sizing signals — is this an epic?

Decide the level mechanically, not by feel. The primary signal is **duration relative to a sprint**;
the secondary signals catch the two common mistakes (an epic that is really a story, and an epic
that is really the whole product).

| Signal observed | Verdict | Corrective action |
|---|---|---|
| Fits in one sprint; a single clear "done"; one persona, one workflow | **Story, not an epic** | Write it directly with `user-story-writing` |
| Too big for one sprint; one coherent outcome; naturally yields 3–10 stories | **Epic** | Define here, then decompose |
| Cannot be finished within a quarter | **Too large for one epic** | Split into multiple epics by outcome or user segment |
| Decomposes into exactly one story | **Not an epic** | Promote that story to a standalone requirement — no epic wrapper |
| "Done" state cannot be described without describing the whole product | **The everything epic** | Cut by outcome until each fragment can independently succeed or fail |
| A bucket holding several epics, used only for release reporting | **Theme, not an epic** | Keep as a grouping label; give it no acceptance criteria |
| The outcome touches two or more Bounded Contexts | **Architectural concern** | Flag for `domain-modeler`; a cleanly single-context epic is the norm |

**Rule of thumb on story count.** Fewer than 3 stories → the "epic" is probably a single story.
More than ~10 → it is probably two epics or a theme. 3–10 is the healthy band.

---

## 3. The epic artifact — annotated template

```
EPIC-[ID]: [Short title — an outcome phrase, never a feature or component name]

As a result of this epic, [actor / persona] will be able to [outcome].

Hypothesis: If we [build this capability], we believe [this actor's behaviour will change
            in this measurable way], which will contribute to [business goal or OKR KR].

Business Goal Link: [OKR Key Result or impact-map goal this epic advances]
Impact Map Link:    [WHAT deliverable(s) from impact-mapping this epic implements]
Personas affected:  [Primary persona; secondary personas]
Bounded Context:    [The single domain this epic primarily belongs to — handoff to domain-modeler]

Acceptance Criteria (epic level — 3-5 HIGH-LEVEL conditions; detailed criteria live on stories):
- [ ] [A high-level condition that must be true when the whole epic is complete]
- [ ] [...]

Decomposition (user stories — TITLES ONLY at epic-definition stage):
- US-001: [Story title — an outcome, not a task]
- US-002: [Story title]
- ...

Priority: [Must / Should / Could / Won't — MoSCoW; see moscow-prioritization]
Estimated size: [S / M / L / XL — relative, not story points]
Phase: [Which SDLC phase this epic is implemented in]
```

**Field notes.**

- **Title** — name the outcome. "A Data Steward sees the full classified estate risk in one screen",
  not "Dashboard". A component name in the title is the single most common epic defect.
- **Hypothesis** — must be *falsifiable*. It buys a crucial distinction: an epic can *succeed*
  (shipped, criteria met) while its hypothesis *fails* (the expected behaviour change did not
  occur), which tells the team the bottleneck is elsewhere rather than "build more of this."
- **Bounded Context** — a single named context. Two or more is a smell to escalate, not to record
  and move on.
- **Decomposition** — titles only. Resist writing story bodies or story-level criteria here.

---

## 4. Epic-level vs story-level acceptance criteria

This is the most misapplied part of epic definition. Keep the two altitudes strictly separate.

| | Epic-level criteria | Story-level criteria |
|---|---|---|
| **Form** | 3–5 plain high-level conditions | **Given/When/Then** (Gherkin) |
| **Answers** | "Is the whole outcome delivered?" | "Does this specific behaviour work, including edges?" |
| **Written** | At epic-definition time (now) | Per story, *after* decomposition, once discovery happened |
| **Owned by** | this skill | `acceptance-criteria` |
| **Cohn's Three Cs** | A promise the outcome will be confirmed | The **Confirmation** leg, detailed |

**Why the altitude matters (Cohn's Three Cs).** A user story is Card + Conversation + Confirmation:
the card defers detail on purpose so the real requirement can emerge in conversation. Writing full
Given/When/Then at epic time freezes guesses into text *before* that conversation — the exact failure
mode Cohn warns against ("don't write novels"). Epic criteria stay high-level precisely so the
detailed Confirmation can be negotiated per story when the team actually knows enough to get it right.

**Good epic-level criterion** (high-level, outcome checkpoint):
> - [ ] A Data Steward can view every classified data source in the estate on one screen, grouped
>       by sensitivity, without exporting to a spreadsheet.

**Wrong at epic time** (story-level detail masquerading as an epic criterion):
> - [ ] Given a source with 0 files, When the Steward opens the estate view, Then an empty-state
>       card reads "No files classified yet" with a "Run classification" button.

The second belongs on story `US-00x` after decomposition — not on the epic.

---

## 5. Worked epic (repo context)

```
EPIC-002: Connect any supported storage source in under 5 minutes

As a result of this epic, the Compliance Officer will be able to connect Google Drive and AWS S3
to the platform without IT assistance.

Hypothesis: If we make source connection a guided, sub-5-minute flow, we believe trial users will
            connect all their storage sources in the first session, which will contribute to KR1.1
            (80% of trial users discover their first compliance gap within 30 minutes).

Business Goal Link: KR1.1
Impact Map Link:    "Guided onboarding wizard", "Pre-built Google Drive OAuth connector"
Personas affected:  Compliance Officer (primary), IT/DevOps Lead (secondary)
Bounded Context:    Source Ingestion

Acceptance Criteria (epic level):
- [ ] A Google Drive can be connected via OAuth without leaving the product UI
- [ ] An S3 bucket can be connected with scoped, read-only credentials
- [ ] A failed connection explains the cause and the fix in plain language

Decomposition (user stories — titles only):
- US-001: Connect Google Drive via OAuth
- US-002: Connect AWS S3 with read-only credentials
- US-003: See connection health and re-authenticate an expired source

Priority: Must
Estimated size: L
Phase: Implement
```

What the hypothesis makes visible: if trial users connect their sources in the first session but
still fail to find a gap within 30 minutes, the epic **succeeded** and the hypothesis **failed** —
the bottleneck is downstream of connection. Without the hypothesis, that signal is invisible and the
team wastes effort "improving onboarding."

---

## 6. Output format — the `epic-list` artifact

```markdown
---
name: epic-list
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
---

# Epic List

## Epic Summary

| ID | Title | Personas | OKR KR | Priority | Size |
|---|---|---|---|---|---|
| EPIC-001 | ... | ... | ... | Must | L |

---

## Epics (Detailed)

### EPIC-001: [Title]
[Full epic format from section 3]

---

### EPIC-002: [Title]
[Full epic format]
```

Optionally add a **Themes** section above the summary when several epics group under a release-level
label — themes carry a title and the epic IDs they contain, and no acceptance criteria.

---

## 7. Readiness checklist (gate before `user-story-writing`)

- [ ] Title is outcome-oriented (no feature/component name)
- [ ] Outcome statement present
- [ ] Falsifiable hypothesis present
- [ ] OKR KR / business goal linked **and** impact-map deliverable linked
- [ ] 3–5 epic-level (high-level) acceptance criteria — no Given/When/Then
- [ ] ≥3 user-story titles listed
- [ ] Single Bounded Context named (or explicit multi-context escalation flag)
- [ ] MoSCoW priority and relative size assigned
