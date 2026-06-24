---
name: user-persona
description: >
  Teaches how to build research-grounded user personas for a B2B product — covering
  persona construction, the key attributes that make a persona actionable (not
  decorative), the difference between a persona and an ICP, and how to connect
  personas to JTBD analysis and user story writing. Used by the requirements-analyst
  agent during the Ideate phase before JTBD analysis begins.
version: 1.0.0
phase: ideate
owner: requirements-analyst
tags: [ideate, persona, user-research, jtbd, product-discovery]
---

# User Persona

## Purpose

A user persona is a composite archetype of a real type of user — not a demographic stereotype, and not a fictional character. A good persona answers: **what is this type of person trying to accomplish, what prevents them from doing it today, and what does success look like to them?**

Personas serve one purpose in this process: to make requirements concrete. "The system must scan files" is ambiguous. "Yuki, the Compliance Officer, must be able to see a gap report across her entire estate within 30 minutes of connecting a source, so she can brief her CISO before the quarterly board meeting" is actionable.

---

## Persona vs ICP

| Concept | Level | Defines |
|---|---|---|
| **ICP (Ideal Customer Profile)** | Company | The type of organisation most likely to buy and get value from the product |
| **User Persona** | Individual | The type of person within that organisation who uses the product |
| **Buyer Persona** | Individual | The type of person who makes the purchase decision (may differ from the user) |

For B2B products, always model at minimum: the primary user, the buyer/economic decision maker, and the internal champion (if different from both). These have different needs, and the product must serve all three to close and retain deals.

---

## Required Persona Attributes

A persona that lacks these attributes cannot be used to write requirements or job stories:

### Identity Anchors
- **Name and role title** — grounded archetype (e.g. "Yuki Tanaka, Compliance Officer")
- **Company profile** — size, industry, regulatory exposure (consistent with ICP)
- **Technical literacy** — how comfortable is this person with technology? Self-serves or needs guidance?
- **Domain expertise** — deep or shallow knowledge of the domain (compliance, data governance, etc.)?

### Motivations and Goals
- **Primary goal** — the one outcome this person most wants to achieve in their work
- **Secondary goals** — 2-3 other outcomes they care about
- **Success metrics** — how does this person measure whether they've succeeded? (What gets them promoted?)

### Frustrations and Blockers
- **Current approach** — how do they accomplish their goal today (without your product)?
- **Primary frustration** — the single biggest pain point with the current approach
- **Secondary frustrations** — 2-3 additional recurring pains

### Behaviours
- **Decision-making style** — analytical (data-driven) / relational (trusts referrals) / spontaneous (early adopter) / methodical (waits for proof)
- **Risk tolerance** — how much uncertainty does this persona accept before buying or adopting a new tool?
- **Information sources** — where does this persona go to learn about new tools? (Analyst reports, peer communities, LinkedIn, vendor webinars)

### Relationship to Product
- **Trigger** — what event causes this persona to start looking for a solution?
- **Expected time to first value** — how quickly does this persona need to see value before they lose patience?
- **Adoption barrier** — what is the most likely reason this persona would abandon the product after trying it?

---

## Persona Anti-Patterns

| Anti-Pattern | Problem |
|---|---|
| Demographic-only persona | Age, gender, and location do not predict product behaviour. Goals and frustrations do. |
| Single persona for a multi-stakeholder product | Missing the buyer means the product never converts. Missing the champion means the buyer never hears about it. |
| Aspirational persona | "Our ideal user is a visionary data leader" is aspirational marketing, not a persona. Model who the user actually is, not who you wish they were. |
| No frustrations | A persona with only goals and no frustrations cannot generate job stories with a real motivation. |
| No current approach | If you don't understand how they do it today, you can't understand why they'd switch. |

---

## How Many Personas?

- **Primary persona** — 1 per product. This is the user the product is designed for first. If the product can only serve one persona well, it serves the primary.
- **Secondary personas** — 1-3. These personas must also be served but are not the design anchor.
- **Anti-persona (excluded user)** — Optional but valuable: explicitly define who the product is NOT designed for. This prevents scope creep and misaligned feature requests.

For the first product (Data Estate Mapping & Compliance Intelligence), minimum three personas:
1. The Compliance Officer / DPO (primary user — drives the compliance workflow)
2. The CISO or VP Engineering (buyer — economic decision maker, wants the assurance story)
3. The IT / DevOps Lead (internal champion and technical implementer — deploys and maintains it)

---

## Step-by-Step Production

1. Review the ICP from the GTM strategy — the persona must live within that ICP company profile.
2. Review the stakeholder map — "Manage Closely" stakeholders often correspond to primary or buyer personas.
3. For each distinct role type in the target company (user, buyer, champion), draft a persona archetype.
4. Validate each attribute against the problem statement: does this frustration actually relate to the problem you're solving?
5. Check for anti-patterns. If the persona has no frustrations, no current approach, or no adoption barrier — it is incomplete.
6. Present personas to Shafi for review before using them in JTBD analysis.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Groundedness | Persona attributes derive from the problem statement, ICP, and stakeholder map | Persona invented without reference to research inputs |
| Actionability | Every attribute can be used to write or validate a requirement or job story | Attributes that are decorative but don't constrain the product |
| Completeness | All required attributes are present | Missing goals, frustrations, or current approach |
| Coverage | At minimum: primary user, buyer, and technical implementer | Single-persona view of a multi-stakeholder product |
| Exclusion clarity | Anti-persona defined or scope boundary stated | Open-ended "anyone with data" user target |

---

## Output Format

```markdown
---
artifact: user-personas
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
primary-persona: [name]
---

# User Personas

## Persona 1: [Name], [Role Title] — PRIMARY

### Identity
- **Company:** [size, industry, regulatory exposure]
- **Technical literacy:** [1-5 scale with description]
- **Domain expertise:** [shallow / working / deep]

### Goals
- **Primary:** [the one outcome they most want]
- **Secondary:** [2-3 others]
- **Success metric:** [what gets them promoted or recognised]

### Frustrations
- **Primary frustration:** [biggest pain with current approach]
- **Secondary frustrations:** [2-3 others]
- **Current approach:** [how they do it today]

### Behaviours
- **Decision-making style:** [analytical / relational / spontaneous / methodical]
- **Risk tolerance:** [low / medium / high]
- **Information sources:** [where they learn about tools]

### Relationship to Product
- **Trigger:** [what causes them to start looking for a solution]
- **Expected time to first value:** [how quickly they need to see value]
- **Adoption barrier:** [most likely reason they'd abandon after trying]

---

## Persona 2: [Name], [Role Title] — BUYER / SECONDARY
[Repeat structure]

---

## Anti-Persona: Who This Product Is NOT For
[Description of the user type explicitly excluded from the primary design target]
```
