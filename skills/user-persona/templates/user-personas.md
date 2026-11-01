# User Personas — Artifact Template

Self-contained. Copy everything inside the fence into `artifacts/<product>/ideate/user-personas.md` and replace every `[bracketed]` value. Repeat the persona block per persona. Delete the sections your profile does not use: at **lean**, drop the behavioural-variable table (keep one line per persona), the feature matrix and the foundation; keep the job stories and forces line, because `jtbd-analysis` is skipped. At **standard**, drop the job stories (they live in `jtbd-analysis`) and usually the matrix and foundation. At **enterprise**, keep everything.

---

```markdown
---
name: user-personas
product: [product name]
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: [YYYY-MM-DD]
summary: [one sentence, ≤ 200 chars — who the primary persona is and what it needs, e.g. "Office manager is the primary of the reminder queue; the managing partner buys; firms' clients are served. Proto, unvalidated."]
profile: [lean | standard | enterprise]
grounding: [proto | mixed | research]
authored-by: requirements-analyst (AI)
evidence: [none | second-hand: <sources> | interviews: <refs to the user's notes>]
review-by: [YYYY-MM-DD]
traces_to: [strategy/gtm-strategy.md (ICP); strategy/stakeholder-map.md §2 (buying committee); the problem statement]
---

# User Personas — [product]

## Persona Set

| Persona | Type | Interface (primaries) | Grounding | Status |
|---|---|---|---|---|
| [Name], [role] | Primary | [surface] | PROTO | active |
| [Name], [role] | [Secondary / Supplemental / Customer / Served] | — | [PROTO / MIXED] | active |
| [Name or group] | Negative | — | PROTO | active |

## Behavioural Variables  <!-- standard and enterprise; at lean, one line inside each persona -->

| Variable (two-ended range) | [Interviewee or "hypothesised: <role>"] | […] |
|---|---|---|
| [Activity: … ↔ …] | [position] | [position] |
| [Attitude: … ↔ …] | | |
| [Aptitude: … ↔ …] | | |
| [Motivation: … ↔ …] | | |
| [Skill: … ↔ …] | | |

**Patterns:** [which people cluster on which variables → which persona; merges and why; gaps]

---

## Persona: [First name], [role]

**Type:** [Primary] · **Interface:** [the surface this persona is the design target for]
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from [inputs] · no user research
**Status:** active

**Role and context:** [role; the company or life context, consistent with the ICP; only facts that drive a requirement] `[source]`
**Distinguishing variables:** [3–5 ranges with this persona's position] `[source]`

### Goals
- **End goals:** [what they want done, solution-free] `[source]`
- **Experience goals:** [how they want to feel while doing it] `[source]`
- **Life goals:** [who they want to be / what gets them recognised — optional for B2B] `[source]`

### Forces and context
- **Current approach (habit):** [today's workaround — what would be fired] `[source]`
- **Primary frustration:** [costliest pain in the current approach] `[source]`
- **Trigger (push):** [the event that ends passive looking] `[source]`
- **Adoption barrier (anxiety):** [most likely reason to abandon after trying] `[source]`
- **Trust in automated output:** [verify-first or accept-once-proven; what erodes it — only where the product drafts, classifies or decides] `[source]`
- **Time to first value:** [how fast before they revert] `[source]`
- **Decision style and information sources:** [customer and secondary personas: what convinces them, where they look] `[source]`

### Job
- **Job statement:** [verb] [object] [clarifier] — solution-free, one line → `jtbd-analysis`
- **Job stories (lean only):** When [situation], I want to [motivation], so I can [outcome].
- **Forces (lean only):** push [ ] · pull [ ] · habit [ ] · anxiety [ ]

### Validation questions
| Attribute | Ask (a specific past event) | Wrong if |
|---|---|---|
| [attribute tagged assumption] | ["Last time …, what did you …?"] | [the answer that overturns it] |

**Recruit first:** [who the user should talk to, and which variable their answer settles]

---

## Persona: [Name or group], [role] — Served

**Type:** Served
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from [inputs] · no user research
**Status:** active

**Role and context:** [who they are; how the product affects them though they never use it] `[source]`
**Constraints on the design:** [what the product must or must not do to them] `[source]`

---

## Negative Persona: [who]

**Type:** Negative
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from [inputs] · no user research
**Status:** active

**Who and why excluded:** [the user the design will not serve, and the scope it would pull in] `[source]`

---

## Persona-Weighted Feature Matrix  <!-- enterprise; optional at standard -->

| Feature or epic | [Persona] (×[weight]) | [Persona] (×[weight]) | Weighted |
|---|---|---|---|
| [feature] | [0–3] | [0–3] | [sum] |

Input to `moscow-prioritization`, not the decision.

## Foundation  <!-- enterprise -->

| Factoid | Source | Supports |
|---|---|---|
| [one fact] | [interview / ticket / report ref] | [persona · attribute] |

## Lifecycle

- **Review by:** [date]
- **Reopen when:** a journey map finds a job no persona covers · a design-partner session contradicts an attribute · the GTM adds a segment or tenant type · the review date passes
- **Retired personas:** [none | name · date · reason · replaced by]

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | [date] | First set | [Ideate start] |
```
