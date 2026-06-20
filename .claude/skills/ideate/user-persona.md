# Skill: ideate/user-persona

## Purpose
Produce a detailed User Persona for one role. Personas are not demographic stereotypes — they are composite representations of real user goals, behaviours, frustrations, and success criteria, grounded in the Jobs To Be Done framework. Each persona becomes a reference anchor for the Story Map, acceptance criteria, and UX design.

## Inputs
Read before generating:
- `artifacts/strategy/stakeholders.md` — must exist (persona is derived from a stakeholder)
- `sdlc-config.json` — product_name
- **Argument required:** persona role name (e.g. "CISO", "IT Administrator", "Compliance Officer")

## Output
**File:** `artifacts/ideate/personas/{role-slug}.md` (e.g. `personas/ciso.md`)
**Registers in manifest:** yes

## Process
1. Read the stakeholder map. Find the stakeholder entry for the requested role.
2. Expand the stakeholder entry into a full persona using the template.
3. Apply Jobs To Be Done framing: functional job (what they do), social job (how they want to be perceived), emotional job (how they want to feel).
4. Define their interaction with the product: entry point, primary workflows, frequency of use, definition of success.
5. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# User Persona: {Role Name}

**Product:** {product_name}
**Phase:** Ideate
**Artifact:** User Persona
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## {Persona Name} — {Role Title}

> "{A one-sentence quote that captures their primary frustration or goal in their own voice.}"

### Who They Are
- **Role:** {job title and function}
- **Organisation type:** {the kind of company they work at}
- **Team size:** {how many people they manage or work with}
- **Technical depth:** {non-technical / semi-technical / technical}
- **Decision authority:** {budget owner / influencer / end user}

### Their World (Context)
{2–3 sentences describing their day-to-day environment, the pressures they operate under, and how they currently handle the problem this product solves.}

### Jobs To Be Done

| Job type | Job statement |
|----------|--------------|
| **Functional** | When {situation}, I want to {motivation}, so I can {outcome}. |
| **Social** | When {situation}, I want to {be perceived as / demonstrate}, so that {social outcome}. |
| **Emotional** | When {situation}, I want to feel {emotional state}, so that {peace of mind / confidence outcome}. |

### Goals
1. {Primary goal — the most important thing they are trying to accomplish}
2. {Secondary goal}
3. {Tertiary goal}

### Frustrations (with current alternatives)
1. {Biggest frustration with how they solve this today}
2. {Second frustration}
3. {Third frustration}

### How They Use the Product

| Dimension | Detail |
|-----------|--------|
| **Entry point** | {How do they first encounter and adopt the product} |
| **Primary workflow** | {The most frequent thing they do in the product} |
| **Usage frequency** | {Daily / Weekly / Monthly / Event-triggered} |
| **Success moment** | {The specific instant when they feel the product has delivered value} |
| **Failure moment** | {What would cause them to abandon the product} |

### Their Definition of Success
{Complete this sentence in their voice: "I know this product is working when..."}

### What They Are NOT
{Explicitly describe what this persona does NOT do, does NOT care about, and does NOT decide — to prevent scope creep and over-serving this persona.}

### Influence on Adoption
- **Champion potential:** {Will they advocate for the product internally? Why or why not?}
- **Veto risk:** {Under what circumstances would they block adoption?}
- **Expansion trigger:** {What would cause them to expand usage or buy more?}
```

## Quality Checks
Before writing:
- [ ] All three JTBD job types are populated
- [ ] "What They Are NOT" section is populated — prevents scope creep
- [ ] Definition of Success is written in the persona's voice, not product language
- [ ] Frustrations are specific to the current alternative, not generic complaints
- [ ] No undefined ubiquitous language terms
